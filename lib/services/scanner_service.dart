import 'dart:io';

class ScannerService {
  static List<FileSystemEntity> scanImages(String folderPath) {
    final directory = Directory(folderPath);

    return directory
        .listSync(recursive: true)
        .where((file) =>
            file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.png') ||
            file.path.toLowerCase().endsWith('.webp'))
        .toList();
  }
}