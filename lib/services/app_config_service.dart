import 'dart:io';

/// Configuration service for the Deck Image Picker application.
/// Provides default paths and environment detection.
class AppConfigService {
  /// Default base directory for image reviews on Steam Deck
  static const String defaultReviewsPath = '/home/deck/Pictures/Reviews';

  /// Check if the application is running on a Steam Deck.
  /// Detects by checking if the HOME environment variable points to /home/deck
  static bool get isSteamDeck {
    return Platform.environment['HOME'] == '/home/deck';
  }

  /// Get the default directory path if it exists and we're on Steam Deck.
  /// Returns null if:
  /// - Not running on Steam Deck
  /// - Default directory doesn't exist
  static String? getDefaultDirectory() {
    if (!isSteamDeck) {
      return null;
    }

    final dir = Directory(defaultReviewsPath);
    return dir.existsSync() ? defaultReviewsPath : null;
  }

  /// Ensure the default directory exists by creating it if necessary.
  /// Returns true if the directory exists or was created successfully.
  /// Returns false if creation failed.
  static Future<bool> ensureDefaultDirectory() async {
    try {
      final dir = Directory(defaultReviewsPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a directory exists at the given path.
  static bool directoryExists(String path) {
    return Directory(path).existsSync();
  }
}
