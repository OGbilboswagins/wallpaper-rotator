import 'package:flutter/material.dart';

class FolderSection extends StatelessWidget {
  final String targetName;
  final String selectedFolder;
  final int imageCount;
  final VoidCallback onSelectFolder;
  final String fitMode;
  final ValueChanged<String?> onFitModeChanged;

  const FolderSection({
    super.key,
    required this.targetName,
    required this.selectedFolder,
    required this.imageCount,
    required this.onSelectFolder,
    required this.fitMode,
    required this.onFitModeChanged,
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

        DropdownButton<String>(
          value: fitMode,
          items: const [
            DropdownMenuItem(value: 'Fit', child: Text('Fit')),
            DropdownMenuItem(value: 'Fill', child: Text('Fill')),
            DropdownMenuItem(value: 'Stretch', child: Text('Stretch')),
            DropdownMenuItem(value: 'Center', child: Text('Center')),
          ],
          onChanged: onFitModeChanged,
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