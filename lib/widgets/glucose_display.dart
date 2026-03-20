import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../utils/unit_converter.dart';

class GlucoseDisplay extends StatelessWidget {
  final double? value; // mmol/L
  final bool useMgdl;
  final String? subtitle;
  final bool isEstimate;

  const GlucoseDisplay({
    super.key,
    required this.value,
    required this.useMgdl,
    this.subtitle,
    this.isEstimate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (value == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '—',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 64,
              fontWeight: FontWeight.w700,
              color: secondaryColor,
            ),
          ),
          Text(
            UnitConverter.unitLabel(useMgdl: useMgdl),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 18,
              color: secondaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    final displayValue = UnitConverter.formatGlucose(value!, useMgdl: useMgdl);
    final unit = UnitConverter.unitLabel(useMgdl: useMgdl);

    // Color-code: normal (3.9–7.8 mmol/L), high, low
    final mmol = value!;
    Color valueColor;
    if (mmol < 3.9) {
      valueColor = AppColors.error;
    } else if (mmol > 7.8) {
      valueColor = AppColors.warning;
    } else {
      valueColor = AppColors.accent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEstimate)
          Text(
            'Est. Glucose',
            style: TextStyle(
              fontSize: 12,
              color: secondaryColor,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              displayValue,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 64,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 6),
              child: Text(
                unit,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 18,
                  color: secondaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
        ],
      ],
    );
  }
}
