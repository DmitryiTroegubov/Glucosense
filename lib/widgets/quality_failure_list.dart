import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Displays a list of quality check failure strings.
/// Each entry is shown with a red X prefix.
class QualityFailureList extends StatelessWidget {
  final List<String> failures;

  const QualityFailureList({super.key, required this.failures});

  @override
  Widget build(BuildContext context) {
    if (failures.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
              SizedBox(width: 6),
              Text(
                'Quality checks failed',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...failures.map(
            (f) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '❌  $f',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
