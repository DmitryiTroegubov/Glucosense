import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../models/calibration_point.dart';
import '../models/personal_model.dart';
import '../providers/model_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../utils/unit_converter.dart';

class ModelDetailScreen extends StatelessWidget {
  final String modelId;
  const ModelDetailScreen({super.key, required this.modelId});

  @override
  Widget build(BuildContext context) {
    final modelProvider = context.watch<ModelProvider>();
    final settings = context.watch<SettingsProvider>();

    final model = modelProvider.allModels.firstWhere((m) => m.id == modelId);

    return Scaffold(
      appBar: AppBar(
        title: Text(model.name),
        actions: [
          if (!model.isDefault)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-fit model',
              onPressed:
                  model.calibrationPointCount >= AppConstants.minCalibrationPoints
                      ? () => modelProvider.refitModelManually(model.id)
                      : null,
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export model',
            onPressed: () async {
              final json = await modelProvider.exportModelJson(model.id);
              Share.share(json, subject: '${model.name}.json');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<CalibrationPoint>>(
        future: modelProvider.getCalibrationPoints(modelId),
        builder: (context, snapshot) {
          final points = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsCard(model: model, useMgdl: settings.useMgdl),
              const SizedBox(height: 16),
              if (points.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No calibration points yet.\nMeasure and save with a reference glucose to begin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ),
                  ),
                )
              else ...[
                _SectionHeader(
                  title:
                      'Calibration Points (${points.length}/${AppConstants.minCalibrationPoints} needed)',
                ),
                ...points.reversed
                    .map((pt) => _CalibrationTile(
                          point: pt,
                          useMgdl: settings.useMgdl,
                          onDelete: model.isDefault
                              ? null
                              : () => _confirmDelete(
                                  context, modelProvider, model.id, pt.id),
                        ))
                    .toList(),
              ],
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ModelProvider mp, String modelId,
      String pointId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete point?'),
        content: const Text(
            'This calibration point will be removed and the model will be re-fitted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              mp.deleteCalibrationPoint(modelId, pointId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final PersonalModel model;
  final bool useMgdl;

  const _StatsCard({required this.model, required this.useMgdl});

  @override
  Widget build(BuildContext context) {
    final ready = model.canPredict;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.check_circle : Icons.pending_outlined,
                  color: ready
                      ? AppColors.success
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 8),
                Text(
                  ready
                      ? 'Model ready'
                      : model.isDefault
                          ? 'Built-in model (placeholder weights)'
                          : '${model.pointsNeeded} more points needed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ready
                        ? AppColors.success
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            if (ready && (model.mardPercent != null || model.rmse != null)) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (model.mardPercent != null)
                    _StatChip(
                      label: 'MARD',
                      value: '${model.mardPercent!.toStringAsFixed(1)}%',
                      good: model.mardPercent! < 15,
                    ),
                  if (model.rmse != null)
                    _StatChip(
                      label: 'RMSE',
                      value:
                          '${UnitConverter.display(model.rmse!, useMgdl).toStringAsFixed(useMgdl ? 1 : 2)} '
                          '${useMgdl ? "mg/dL" : "mmol/L"}',
                      good: model.rmse! < 1.0,
                    ),
                  _StatChip(
                    label: 'Points',
                    value: '${model.calibrationPointCount}',
                    good: model.calibrationPointCount >= 12,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool good;

  const _StatChip(
      {required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: good ? AppColors.success : AppColors.warning,
            )),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondaryLight)),
      ],
    );
  }
}

class _CalibrationTile extends StatelessWidget {
  final CalibrationPoint point;
  final bool useMgdl;
  final VoidCallback? onDelete;

  const _CalibrationTile({
    required this.point,
    required this.useMgdl,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    final ref = UnitConverter.display(point.referenceGlucose, useMgdl);
    final unit = useMgdl ? 'mg/dL' : 'mmol/L';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            ref.toStringAsFixed(useMgdl ? 0 : 1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          '${ref.toStringAsFixed(useMgdl ? 0 : 1)} $unit (ref)',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          fmt.format(point.timestamp),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppColors.textSecondaryLight),
      ),
    );
  }
}
