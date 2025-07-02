import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:carmod_ar/utils/constants.dart';
import 'package:carmod_ar/utils/detection_painter.dart';
import 'dart:async'; // Import for Completer

class ImageAnalysisScreen extends StatefulWidget {
  final XFile imageFile;

  const ImageAnalysisScreen({Key? key, required this.imageFile}) : super(key: key);

  @override
  _ImageAnalysisScreenState createState() => _ImageAnalysisScreenState();
}

class _ImageAnalysisScreenState extends State<ImageAnalysisScreen> {
  List<Map<String, dynamic>> _detections = [];
  bool _isLoading = false;
  Image? _loadedImage;
  Size? _imageNaturalSize;
  bool? _isCar; // Add this variable to track if the image contains a car

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() async {
    final Image image = Image.file(File(widget.imageFile.path));
    final Completer<Size> completer = Completer<Size>();
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }),
    );
    _imageNaturalSize = await completer.future;
    setState(() {
      _loadedImage = image;
    });
    
    // Automatically analyze the image once it's loaded
    _analyzeImage();
  }


Future<void> _analyzeImage() async {
  setState(() {
    _isLoading = true;
    _detections = [];
    _isCar = null;
  });

  try {
    final bytes = await widget.imageFile.readAsBytes();
    final uri = Uri.parse('$kBaseUrl/detect');

    // 🔥 Create a multipart request
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file', // this is the field name your FastAPI expects
          bytes,
          filename: 'image.png', // give it any name
        ),
      );

    // 🔥 Send the request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _detections = List<Map<String, dynamic>>.from(data['detections']);
        _isCar = data['is_car'] ?? false;
      });
      print("RESPONSE ${_detections}   , ${_isCar}");

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error from API: ${response.statusCode} ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error analyzing image: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: const Text('Analyze Image'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: _loadedImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Car detection status banner
                if (_isCar != null)
                  Container(
                    width: double.infinity,
                    color: _isCar! ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        _isCar! ? 'Car Detected ✓' : 'No Car Detected ✗',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        children: [
                          _loadedImage!,
                          CustomPaint(
                            painter: BoundingBoxPainter(
                              detections: _detections,
                              imageSize: _imageNaturalSize,
                              displaySize: Size(constraints.maxWidth, constraints.maxHeight),
                            ),
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                // Detection summary
                if (_detections.isNotEmpty && !_isLoading)
                  Container(
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected ${_detections.length} car part${_detections.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _detections.map((d) => d['class_name']).toSet().join(', '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        foregroundColor: Colors.blueGrey[990],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _analyzeImage,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey[900]!), 
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.analytics),
                      label: _isLoading
                          ? const Text('Analyzing...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                          : const Text('Analyze Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 