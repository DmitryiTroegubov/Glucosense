import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/personal_model.dart';
import '../theme/colors.dart';
import '../core/constants.dart';

class ModelCard extends StatelessWidget {
  final PersonalModel model;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onInfo;
  final VoidCallback onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  const ModelCard({
    super.key,
    required this.model,
    required this.isActive,
    required this.onTap,
    this.onInfo,
    required this.onExport,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.dividerLight.withOpacity(0.5),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isActive)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            model.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AppColors.primary : null,
                            ),
                          ),
                        ),
                        if (model.isDefault)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Built-in',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onInfo != null)
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      tooltip: 'Model details',
                      onPressed: onInfo,
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'rename' && onRename != null) onRename!();
                      if (v == 'export') onExport();
                      if (v == 'delete' && onDelete != null) onDelete!();
                    },
                    itemBuilder: (_) => [
                      if (onRename != null)
                        const PopupMenuItem(
                            value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(
                          value: 'export', child: Text('Export JSON')),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(
                    icon: Icons.calendar_today,
                    label: DateFormat('MMM d, yyyy').format(model.createdAt),
                  ),
                  const SizedBox(width: 16),
                  _Stat(
                    icon: Icons.science,
                    label: '${model.calibrationPointCount} cal pts',
                  ),
                ],
              ),
              if (model.canPredict) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (model.mardPercent != null)
                      _Stat(
                        icon: Icons.percent,
                        label:
                            'MARD: ${model.mardPercent!.toStringAsFixed(1)}%',
                        color: _mardColor(model.mardPercent!),
                      ),
                    if (model.mardPercent != null) const SizedBox(width: 16),
                    if (model.rmse != null)
                      _Stat(
                        icon: Icons.straighten,
                        label: 'RMSE: ${model.rmse!.toStringAsFixed(2)}',
                      ),
                  ],
                ),
              ] else if (!model.isDefault) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: model.calibrationPointCount /
                      AppConstants.minCalibrationPoints.toDouble(),
                  backgroundColor: AppColors.dividerLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need ${model.pointsNeeded} more calibration point${model.pointsNeeded == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _mardColor(double mard) {
    if (mard <= 10) return AppColors.qualityGood;
    if (mard <= 20) return AppColors.qualityWarn;
    return AppColors.qualityBad;
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Stat({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
