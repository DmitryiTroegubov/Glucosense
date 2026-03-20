import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';
import '../theme/colors.dart';

class GlucoseChart extends StatelessWidget {
  final List<Measurement> measurements;
  final bool useMgdl;

  const GlucoseChart({
    super.key,
    required this.measurements,
    required this.useMgdl,
  });

  @override
  Widget build(BuildContext context) {
    final points = measurements
        .where((m) => m.qualityPassed && m.predictedGlucose != null)
        .toList()
        .reversed
        .toList();

    if (points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No data yet',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }

    double toDisplay(double mmol) =>
        useMgdl ? mmol * 18.018 : mmol;

    final spots = points.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        toDisplay(e.value.predictedGlucose!),
      );
    }).toList();

    final refSpots = points.asMap().entries
        .where((e) => e.value.referenceGlucose != null)
        .map((e) => FlSpot(
              e.key.toDouble(),
              toDisplay(e.value.referenceGlucose!),
            ))
        .toList();

    final minY = useMgdl ? 40.0 : 2.0;
    final maxY = useMgdl ? 400.0 : 22.0;
    final unit = useMgdl ? 'mg/dL' : 'mmol/L';

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.dividerLight.withOpacity(0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (v, _) => Text(
                    useMgdl ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: (points.length / 4).ceilToDouble().clamp(1, 20),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox();
                    return Text(
                      DateFormat('MM/dd').format(points[idx].timestamp),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondaryLight,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              // Predicted line
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.primary,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withOpacity(0.08),
                ),
              ),
              // Reference dots
              if (refSpots.isNotEmpty)
                LineChartBarData(
                  spots: refSpots,
                  isCurved: false,
                  color: AppColors.accent,
                  barWidth: 0,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.accent,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) {
                  return spots.map((s) {
                    final isRef = s.barIndex == 1;
                    return LineTooltipItem(
                      '${isRef ? 'Ref' : 'Est'}: ${s.y.toStringAsFixed(useMgdl ? 0 : 1)} $unit',
                      TextStyle(
                        color: isRef ? AppColors.accent : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
