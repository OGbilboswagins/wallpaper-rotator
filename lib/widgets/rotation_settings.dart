import 'package:flutter/material.dart';

class RotationSettings extends StatelessWidget {
  final String interval;
  final bool rotationEnabled;
  final ValueChanged<String?> onIntervalChanged;
  final ValueChanged<bool> onRotationChanged;

  const RotationSettings({
    super.key,
    required this.interval,
    required this.rotationEnabled,
    required this.onIntervalChanged,
    required this.onRotationChanged,
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
          items: const [
            DropdownMenuItem(value: '10 seconds', child: Text('10 seconds')),
            DropdownMenuItem(value: '30 seconds', child: Text('30 seconds')),
            DropdownMenuItem(value: '1 minute', child: Text('1 minute')),
            DropdownMenuItem(value: '15 minutes', child: Text('15 minutes')),
            DropdownMenuItem(value: '30 minutes', child: Text('30 minutes')),
            DropdownMenuItem(value: '1 hour', child: Text('1 hour')),
            DropdownMenuItem(value: '4 hours', child: Text('4 hours')),
            DropdownMenuItem(value: 'Daily', child: Text('Daily')),
          ],
          onChanged: onIntervalChanged,
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