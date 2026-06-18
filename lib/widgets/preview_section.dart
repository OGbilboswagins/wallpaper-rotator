import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class PreviewSection extends StatelessWidget {
  final String selectedImagePath;

  const PreviewSection({
    super.key,
    required this.selectedImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectedImagePath.isNotEmpty)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                border: Border.all(),
              ),
              child: Image.file(
                File(selectedImagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),

        const SizedBox(height: 8),

        Text(
          'Selected Image: ${p.basename(selectedImagePath)}',
        ),
      ],
    );
  }
}