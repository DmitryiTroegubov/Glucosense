import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/measurement.dart';
import '../providers/app_state.dart';
import '../providers/model_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../utils/unit_converter.dart';
import '../widgets/glucose_chart.dart';

enum _Filter { all, passed, rejected, calibrated }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final models = context.watch<ModelProvider>();
    final settings = context.watch<SettingsProvider>();

    final allHistory = appState.measurements;

    final filtered = allHistory.where((m) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.passed:
          return m.qualityPassed;
        case _Filter.rejected:
          return !m.qualityPassed;
        case _Filter.calibrated:
          return m.referenceGlucose != null;
      }
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Chart
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: GlucoseChart(
                measurements: filtered.take(50).toList(),
                useMgdl: settings.useMgdl,
              ),
            ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _Filter.values
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_filterLabel(f)),
                          selected: _filter == f,
                          onSelected: (_) =>
                              setState(() => _filter = f),
                          selectedColor:
                              AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                        ),
                      ))
                  .toList(),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No measurements yet',
                      style: TextStyle(
                          color: AppColors.textSecondaryLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _MeasurementTile(
                      measurement: filtered[i],
                      useMgdl: settings.useMgdl,
                      modelName: _modelName(
                          filtered[i].modelId, models),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.passed:
        return 'Passed';
      case _Filter.rejected:
        return 'Rejected';
      case _Filter.calibrated:
        return 'Calibrated';
    }
  }

  String? _modelName(String modelId, ModelProvider models) {
    if (modelId.isEmpty) return null;
    try {
      return models.allModels.firstWhere((m) => m.id == modelId).name;
    } catch (_) {
      return null;
    }
  }
}

class _MeasurementTile extends StatelessWidget {
  final Measurement measurement;
  final bool useMgdl;
  final String? modelName;

  const _MeasurementTile({
    required this.measurement,
    required this.useMgdl,
    this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final timeStr = DateFormat('MMM d, HH:mm').format(m.timestamp);

    Color statusColor;
    IconData statusIcon;
    if (!m.qualityPassed) {
      statusColor = AppColors.error;
      statusIcon = Icons.warning_rounded;
    } else if (m.predictedGlucose == null) {
      statusColor = AppColors.warning;
      statusIcon = Icons.help_outline;
    } else {
      final v = m.predictedGlucose!;
      if (v < 3.9 || v > 7.8) {
        statusColor = AppColors.warning;
        statusIcon = Icons.trending_up;
      } else {
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                if (!m.qualityPassed)
                  const Chip(
                    label: Text('Rejected',
                        style: TextStyle(fontSize: 10)),
                    backgroundColor: AppColors.error,
                    labelStyle: TextStyle(color: Colors.white),
                    padding: EdgeInsets.zero,
                  ),
                if (m.qualityPassed && m.predictedGlucose != null)
                  Text(
                    '${UnitConverter.formatGlucose(m.predictedGlucose!, useMgdl: useMgdl)} '
                    '${UnitConverter.unitLabel(useMgdl: useMgdl)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: statusColor,
                    ),
                  ),
              ],
            ),
            if (m.referenceGlucose != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.bloodtype,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Ref: ${UnitConverter.formatGlucose(m.referenceGlucose!, useMgdl: useMgdl)} '
                    '${UnitConverter.unitLabel(useMgdl: useMgdl)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _small('PI', m.pi.toStringAsFixed(1)),
                _small('Corr', m.correlation.toStringAsFixed(2)),
                _small('SpO₂', '${m.spo2.toStringAsFixed(0)}%'),
                _small('BPM', m.bpm.toStringAsFixed(0)),
                if (modelName != null) _small('Model', modelName!),
              ],
            ),
            if (m.qualityFailures.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                m.qualityFailures.join(' • '),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _small(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondaryLight)),
        Text(value,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
