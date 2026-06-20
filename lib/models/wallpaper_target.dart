import 'dart:io';

class WallpaperTarget {
  final String name;
  String folderPath;
  List<FileSystemEntity> files;
  String selectedImagePath;
  String lastImagePath;

  WallpaperTarget({
    required this.name,
    this.folderPath = '',
    this.files = const [],
    this.selectedImagePath = '',
    this.lastImagePath = '',
  });
}