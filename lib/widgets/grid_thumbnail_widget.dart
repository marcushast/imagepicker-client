import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/image_item.dart';

/// Widget that displays a thumbnail in the grid view with status and focus indicators.
class GridThumbnailWidget extends StatelessWidget {
  final ImageItem imageItem;
  final ui.Image? thumbnail;
  final bool isFocused;
  final double height;
  final VoidCallback? onTap;

  const GridThumbnailWidget({
    super.key,
    required this.imageItem,
    this.thumbnail,
    this.isFocused = false,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status border color
    Color? statusColor;
    switch (imageItem.status) {
      case ImageStatus.pick:
        statusColor = Colors.green;
        break;
      case ImageStatus.reject:
        statusColor = Colors.red;
        break;
      case ImageStatus.none:
        statusColor = null;
        break;
    }

    // Calculate width from thumbnail's actual aspect ratio
    double width = height; // Default to square if no thumbnail yet
    if (thumbnail != null) {
      final aspectRatio = thumbnail!.width / thumbnail!.height;
      width = height * aspectRatio;
    }

    Widget content;
    if (thumbnail != null) {
      // Display cached thumbnail at its natural aspect ratio
      content = CustomPaint(
        painter: _ThumbnailPainter(thumbnail!),
        child: SizedBox(width: width, height: height),
      );
    } else {
      // Placeholder while loading
      content = Container(
        width: width,
        height: height,
        color: Colors.grey[800],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        ),
      );
    }

    // Wrap with status border
    Widget result = Container(
      decoration: BoxDecoration(
        border: statusColor != null
            ? Border.all(color: statusColor, width: 3)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(statusColor != null ? 1 : 4),
        child: content,
      ),
    );

    // Add focus indicator
    if (isFocused) {
      result = Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.yellow, width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: result,
      );
    }

    // Add tap handler
    return GestureDetector(
      onTap: onTap,
      child: result,
    );
  }
}

/// Custom painter for thumbnail display
class _ThumbnailPainter extends CustomPainter {
  final ui.Image image;

  _ThumbnailPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Draw the full image to fill the canvas (aspect ratio already matched)
    final Rect sourceRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final Rect destinationRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
