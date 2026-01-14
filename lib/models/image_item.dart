import 'dart:io';

enum ImageStatus { none, pick, reject }

class ImageItem {
  final File file;
  ImageStatus status;
  bool isNewGroup;

  ImageItem({
    required this.file,
    this.status = ImageStatus.none,
    this.isNewGroup = false,
  });

  String get fileName => file.path.split('/').last;
  String get filePath => file.path;

  // Serialize to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'filePath': file.path,
      'status': status.name,
      'isNewGroup': isNewGroup,
    };
  }

  // Deserialize from JSON Map
  static ImageItem fromJson(Map<String, dynamic> json, File file) {
    return ImageItem(
      file: file,
      status: _parseStatus(json['status'] as String?),
      isNewGroup: json['isNewGroup'] as bool? ?? false,
    );
  }

  // Parse status string with fallback to none
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
