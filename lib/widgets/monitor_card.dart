import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class MonitorCard extends StatelessWidget {
  final String targetName;
  final String selectedFolder;
  final int imageCount;
  final VoidCallback onSelectFolder;
  final String selectedImagePath;

  const MonitorCard({
    super.key,
    required this.targetName,
    required this.selectedFolder,
    required this.imageCount,
    required this.onSelectFolder,
    required this.selectedImagePath,
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

        if (selectedImagePath.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 20),
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(),
            ),
            child: Image.file(
              File(selectedImagePath),
              fit: BoxFit.contain,
            ),
          ),

        if (selectedImagePath.isNotEmpty)
          Text(
            'Selected Image: ${p.basename(selectedImagePath)}',
          ),

        const SizedBox(height: 20),
      ],
    );
  }
}
