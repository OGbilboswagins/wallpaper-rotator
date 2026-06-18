import 'package:flutter/material.dart';

class FolderSection extends StatelessWidget {
  final String selectedFolder;
  final int imageCount;
  final VoidCallback onSelectFolder;

  const FolderSection({
    super.key,
    required this.selectedFolder,
    required this.imageCount,
    required this.onSelectFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Wallpaper folder',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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