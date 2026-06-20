import 'package:flutter/material.dart';

class FolderSection extends StatelessWidget {
  final String targetName;
  final String selectedFolder;
  final int imageCount;
  final VoidCallback onSelectFolder;

  const FolderSection({
    super.key,
    required this.targetName,
    required this.selectedFolder,
    required this.imageCount,
    required this.onSelectFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          targetName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        const Text('Wallpaper folder'),

        const SizedBox(height: 8),

        Text(selectedFolder),

        const SizedBox(height: 8),

        Text(
          'Images Found: $imageCount',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: onSelectFolder,
          child: const Text('Select Folder'),
        ),
      ],
    );
  }
}