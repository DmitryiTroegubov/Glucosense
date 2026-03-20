import 'package:flutter/material.dart';

/// Circular progress indicator showing phase time remaining.
/// Used during STABILIZING and COLLECTING states.
class PhaseProgress extends StatelessWidget {
  final double value; // 0.0 → 1.0
  final Color color;
  final int remainingSeconds;
  final String label;

  const PhaseProgress({
    super.key,
    required this.value,
    required this.color,
    required this.remainingSeconds,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value.clamp(0.0, 1.0),
                color: color,
                backgroundColor: color.withOpacity(0.15),
                strokeWidth: 8,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${remainingSeconds}s',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
