import 'dart:io';

class WallpaperTarget {
  final String name;
  String folderPath;
  List<FileSystemEntity> files;
  String selectedImagePath;
  String lastImagePath;
  String fitMode;

  WallpaperTarget({
    required this.name,
    this.folderPath = '',
    this.files = const [],
    this.selectedImagePath = '',
    this.lastImagePath = '',
    this.fitMode = 'Fit',
  });
}