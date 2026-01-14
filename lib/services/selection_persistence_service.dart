import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/image_item.dart';

class SelectionPersistenceService {
  static const String _saveFileName = '.deck-selections.json';
  static const String _version = '1.0';

  /// Get the save file path for a given directory
  static String _getSaveFilePath(String directoryPath) {
    return path.join(directoryPath, _saveFileName);
  }

  /// Save selections to JSON file
  /// Returns true if successful, false otherwise
  static Future<bool> saveSelections({
    required String directoryPath,
    required List<ImageItem> images,
  }) async {
    try {
      final saveFilePath = _getSaveFilePath(directoryPath);
      final saveFile = File(saveFilePath);

      // Filter to only save images with non-none status or isNewGroup marker
      final selectionsToSave = images
          .where((img) => img.status != ImageStatus.none || img.isNewGroup)
          .map((img) => img.toJson())
          .toList();

      final data = {
        'version': _version,
        'savedAt': DateTime.now().toIso8601String(),
        'folder': directoryPath,
        'selections': selectionsToSave,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await saveFile.writeAsString(jsonString);

      print(
        'Successfully saved ${selectionsToSave.length} selections to $saveFilePath',
      );
      return true;
    } catch (e) {
      // Log error but don't crash app
      print('Error saving selections: $e');
      return false;
    }
  }

  /// Load selections from JSON file and apply to images
  /// Returns updated images list with restored statuses
  static Future<List<ImageItem>> loadSelections({
    required String directoryPath,
    required List<ImageItem> images,
  }) async {
    try {
      final saveFilePath = _getSaveFilePath(directoryPath);
      final saveFile = File(saveFilePath);

      // Check if save file exists
      if (!await saveFile.exists()) {
        return images; // No save file, return images unchanged
      }

      // Read and parse JSON
      final jsonString = await saveFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate version (future-proofing for migration)
      final version = data['version'] as String?;
      if (version != _version) {
        print(
          'Warning: Save file version mismatch. Expected $_version, got $version',
        );
        // For now, proceed anyway. In future, could add migration logic here.
      }

      // Create a map of file path -> status for quick lookup
      final selections = data['selections'] as List<dynamic>;
      final statusMap = <String, ImageStatus>{};
      final isNewGroupMap = <String, bool>{};

      for (final selection in selections) {
        final selectionMap = selection as Map<String, dynamic>;
        final filePath = selectionMap['filePath'] as String;
        final statusString = selectionMap['status'] as String?;
        final status = _parseStatus(statusString);
        statusMap[filePath] = status;
        isNewGroupMap[filePath] = selectionMap['isNewGroup'] as bool? ?? false;
      }

      // Apply saved statuses and isNewGroup to matching images
      for (final image in images) {
        if (statusMap.containsKey(image.filePath)) {
          image.status = statusMap[image.filePath]!;
        }
        if (isNewGroupMap.containsKey(image.filePath)) {
          image.isNewGroup = isNewGroupMap[image.filePath]!;
        }
      }

      return images;
    } catch (e) {
      // Log error but don't crash app - return images unchanged
      print('Error loading selections: $e');
      return images;
    }
  }

  /// Check if a save file exists for a directory
  static Future<bool> hasSaveFile(String directoryPath) async {
    try {
      final saveFilePath = _getSaveFilePath(directoryPath);
      final saveFile = File(saveFilePath);
      return await saveFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete the save file for a directory
  static Future<bool> deleteSaveFile(String directoryPath) async {
    try {
      final saveFilePath = _getSaveFilePath(directoryPath);
      final saveFile = File(saveFilePath);
      if (await saveFile.exists()) {
        await saveFile.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting save file: $e');
      return false;
    }
  }

  /// Parse status string with fallback to none
  static ImageStatus _parseStatus(String? statusString) {
    if (statusString == null) return ImageStatus.none;

    try {
      return ImageStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => ImageStatus.none,
      );
    } catch (e) {
      return ImageStatus.none;
    }
  }
}
