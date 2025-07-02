import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:carmod_ar/utils/constants.dart';
import 'image_analysis_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _detections = [];
  Timer? _timer;
  bool _isCaptureButtonEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _controller = CameraController(
        cameras![0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startDetection();
      }
    }
  }

  void _startDetection() {
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isProcessing && _controller != null && _controller!.value.isInitialized) {
        _processImage();
      }
    });
  }

  Future<void> _processImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      
      final response = await http.post(
        Uri.parse('$kBaseUrl/detect'),
        body: bytes,
        headers: {'Content-Type': 'image/jpeg'},
      );

      // Delete the temporary file
      await File(image.path).delete();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _detections = List<Map<String, dynamic>>.from(data['detections']);
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || !_isCaptureButtonEnabled) return;

    setState(() {
      _isCaptureButtonEnabled = false;
    });

    try {
      // Pause the detection timer
      _timer?.cancel();
      
      // Take a high-quality picture
      final XFile image = await _controller!.takePicture();
      
      // Navigate to the analysis screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageAnalysisScreen(imageFile: image),
          ),
        ).then((_) {
          // Resume detection when returning from analysis screen
          _startDetection();
          setState(() {
            _isCaptureButtonEnabled = true;
          });
        });
      }
    } catch (e) {
      print('Error capturing image: $e');
      // Resume detection if there was an error
      _startDetection();
      setState(() {
        _isCaptureButtonEnabled = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Car Parts Detection'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          CustomPaint(
            painter: BoundingBoxPainter(
              detections: _detections,
              previewSize: Size(
                _controller!.value.previewSize!.height,
                _controller!.value.previewSize!.width,
              ),
            ),
            size: Size.infinite,
          ),
          // Status indicator
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isProcessing ? Colors.orange : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isProcessing ? 'Processing' : 'Ready',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCaptureButtonEnabled ? _captureAndAnalyze : null,
        backgroundColor: _isCaptureButtonEnabled ? Colors.lightBlueAccent : Colors.grey,
        child: Icon(
          Icons.camera,
          color: Colors.blueGrey[900],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var detection in detections) {
      final bbox = detection['bbox'] as List<dynamic>;
      final confidence = detection['confidence'] as double;
      final classId = detection['class_id'] as int;
      final className = detection['class_name'] as String;

      // Convert normalized coordinates to screen coordinates
      final left = bbox[0] * size.width;
      final top = bbox[1] * size.height;
      final right = bbox[2] * size.width;
      final bottom = bbox[3] * size.height;

      // Draw bounding box
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      // Draw label
      final label = '$className (${(confidence * 100).toStringAsFixed(1)}%)';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 14,
          backgroundColor: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(left, top - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 