import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size? imageSize; // Size of the image being displayed (actual pixels)
  final Size displaySize; // Size of the widget displaying the image

  BoundingBoxPainter({
    required this.detections,
    this.imageSize,
    required this.displaySize,
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

    // Calculate scaling factors
    double scaleX = 1.0;
    double scaleY = 1.0;
    if (imageSize != null) {
      scaleX = displaySize.width / imageSize!.width;
      scaleY = displaySize.height / imageSize!.height;
    }

    for (var detection in detections) {
      final bbox = detection['bbox'] as List<dynamic>;
      final confidence = detection['confidence'] as double;
      // final classId = detection['class_id'] as int; // Not used in drawing
      final className = detection['class_name'] as String;

      // Convert normalized coordinates to display coordinates
      // Bbox format: [x_min, y_min, x_max, y_max] where values are 0-1 (normalized)
      final left = bbox[0] * displaySize.width;
      final top = bbox[1] * displaySize.height;
      final right = bbox[2] * displaySize.width;
      final bottom = bbox[3] * displaySize.height;

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
      
      // Position the text above the bounding box
      textPainter.paint(canvas, Offset(left, top - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 