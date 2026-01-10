import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Widget that displays an image from a pre-decoded ui.Image or falls back to loading from file
class CachedImageWidget extends StatelessWidget {
  final File file;
  final ui.Image? cachedImage;
  final BoxFit fit;

  const CachedImageWidget({
    super.key,
    required this.file,
    this.cachedImage,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // If we have a cached decoded image, use it for instant display
    if (cachedImage != null) {
      return CustomPaint(
        painter: _CachedImagePainter(cachedImage!, fit),
        child: const SizedBox.expand(),
      );
    }

    // Fallback to standard Image.file if not cached
    return Image.file(
      file,
      fit: fit,
    );
  }
}

/// Custom painter to draw a pre-decoded ui.Image
class _CachedImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  _CachedImagePainter(this.image, this.fit);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Calculate the destination rectangle based on BoxFit
    final imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final FittedSizes fittedSizes = applyBoxFit(fit, imageSize, size);
    final Size destinationSize = fittedSizes.destination;

    // Center the image
    final double dx = (size.width - destinationSize.width) / 2;
    final double dy = (size.height - destinationSize.height) / 2;

    final Rect destinationRect = Rect.fromLTWH(
      dx,
      dy,
      destinationSize.width,
      destinationSize.height,
    );

    final Rect sourceRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // Draw the image
    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CachedImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.fit != fit;
  }
}
