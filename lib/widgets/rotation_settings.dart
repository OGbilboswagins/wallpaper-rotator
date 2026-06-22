import 'package:flutter/material.dart';

class RotationSettings extends StatelessWidget {
  final String interval;
  final List<String> allowedIntervals;
  final bool rotationEnabled;
  final ValueChanged<String?> onIntervalChanged;
  final ValueChanged<bool> onRotationChanged;
  final String globalFitMode;
  final ValueChanged<String?> onFitModeChanged;

  const RotationSettings({
    super.key,
    required this.interval,
    required this.allowedIntervals,
    required this.rotationEnabled,
    required this.onIntervalChanged,
    required this.onRotationChanged,
    required this.globalFitMode,
    required this.onFitModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Rotation interval',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        DropdownButton<String>(
          value: interval,
          items: allowedIntervals
              .map(
                (interval) => DropdownMenuItem(
                  value: interval,
                  child: Text(interval),
                ),
              )
              .toList(),
          onChanged: onIntervalChanged,
        ),

        const SizedBox(height: 16),

        const Text(
          'Wallpaper fit mode',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        DropdownButton<String>(
          value: globalFitMode,
          items: const [
            DropdownMenuItem(value: 'Fit', child: Text('Fit')),
            DropdownMenuItem(value: 'Fill', child: Text('Fill')),
            DropdownMenuItem(value: 'Stretch', child: Text('Stretch')),
            DropdownMenuItem(value: 'Center', child: Text('Center')),
          ],
          onChanged: onFitModeChanged,
        ),

        const SizedBox(height: 12),

        SwitchListTile(
          title: const Text('Rotation enabled'),
          value: rotationEnabled,
          onChanged: onRotationChanged,
        ),
      ],
    );
  }
}