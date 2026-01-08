import 'dart:io';
import 'package:path/path.dart' as p;

/// Information about a folder containing images for review.
/// Used by the subfolder picker to display folder metadata.
class FolderInfo {
  /// The display name of the folder (last component of the path)
  final String name;

  /// The full absolute path to the folder
  final String path;

  /// Number of image files in the folder
  final int imageCount;

  /// Whether the folder contains a .deck-selections.json file
  final bool hasSelections;

  /// Last modification time of the folder
  final DateTime lastModified;

  FolderInfo({
    required this.name,
    required this.path,
    required this.imageCount,
    required this.hasSelections,
    required this.lastModified,
  });

  /// Supported image file extensions (case-insensitive)
  static final List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
  ];

  /// Create a FolderInfo instance from a Directory.
  /// Scans the directory to count images and check for selections file.
  static Future<FolderInfo> fromDirectory(Directory dir) async {
    final folderPath = dir.path;
    final folderName = p.basename(folderPath);

    // Count image files in the directory
    int imageCount = 0;
    bool hasSelections = false;

    try {
      final files = dir.listSync();

      for (final file in files) {
        if (file is File) {
          final fileName = file.path.toLowerCase();
          final baseFileName = p.basename(fileName);

          // Check if it's an image file
          if (supportedExtensions.any((ext) => fileName.endsWith(ext))) {
            imageCount++;
          }

          // Check if it's the selections file
          if (baseFileName == '.deck-selections.json') {
            hasSelections = true;
          }
        }
      }
    } catch (e) {
      // If we can't read the directory, return with zero count
      imageCount = 0;
    }

    // Get last modified time
    final stat = await dir.stat();
    final lastModified = stat.modified;

    return FolderInfo(
      name: folderName,
      path: folderPath,
      imageCount: imageCount,
      hasSelections: hasSelections,
      lastModified: lastModified,
    );
  }

  /// Check if a file is an image based on its extension.
  static bool isImageFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return supportedExtensions.any((ext) => lowerPath.endsWith(ext));
  }
}
