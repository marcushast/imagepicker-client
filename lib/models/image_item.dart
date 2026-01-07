import 'dart:io';

enum ImageStatus {
  none,
  pick,
  reject,
}

class ImageItem {
  final File file;
  ImageStatus status;

  ImageItem({
    required this.file,
    this.status = ImageStatus.none,
  });

  String get fileName => file.path.split('/').last;
  String get filePath => file.path;
}
