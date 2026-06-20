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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              targetName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

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

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: onSelectFolder,
              child: const Text('Select Folder'),
            ),

            if (selectedImagePath.isNotEmpty) ...[
              const SizedBox(height: 16),

              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(selectedImagePath),
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Selected Image: ${p.basename(selectedImagePath)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
