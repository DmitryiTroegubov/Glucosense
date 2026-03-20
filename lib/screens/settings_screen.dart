import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Device'),
          _card([
            ListTile(
              title: const Text('Device Name'),
              subtitle: Text(settings.deviceName),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _editText(context, 'Device Name',
                  settings.deviceName, settings.setDeviceName),
            ),
          ]),
          const SizedBox(height: 16),

          _sectionHeader('Quality Thresholds'),
          _card([
            _ThresholdTile(
              label: 'Min Correlation',
              value: settings.minCorrelation.toStringAsFixed(2),
              onTap: () => _editDouble(
                context,
                'Min Correlation',
                settings.minCorrelation,
                settings.setMinCorrelation,
                min: 0.0,
                max: 1.0,
              ),
            ),
            const Divider(height: 0),
            _ThresholdTile(
              label: 'Min Perfusion Index (PI)',
              value: settings.minPI.toStringAsFixed(1),
              onTap: () => _editDouble(
                context,
                'Min PI',
                settings.minPI,
                settings.setMinPI,
                min: 0.0,
                max: 100.0,
              ),
            ),
            const Divider(height: 0),
            _ThresholdTile(
              label: 'Max Drift (DC change)',
              value: settings.maxDrift.toStringAsFixed(0),
              onTap: () => _editDouble(
                context,
                'Max Drift',
                settings.maxDrift,
                settings.setMaxDrift,
                min: 0.0,
                max: 5000.0,
              ),
            ),
            const Divider(height: 0),
            _ThresholdTile(
              label: 'Min Beats in Window',
              value: settings.minBeats.toString(),
              onTap: () => _editInt(
                context,
                'Min Beats',
                settings.minBeats,
                settings.setMinBeats,
                min: 1,
                max: 30,
              ),
            ),
            const Divider(height: 0),
            _ThresholdTile(
              label: 'Min Samples',
              value: settings.minSamples.toString(),
              onTap: () => _editInt(
                context,
                'Min Samples',
                settings.minSamples,
                settings.setMinSamples,
                min: 10,
                max: 500,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _sectionHeader('Display'),
          _card([
            SwitchListTile(
              title: const Text('Use mg/dL'),
              subtitle: const Text('Default: mmol/L'),
              value: settings.useMgdl,
              onChanged: settings.setUseMgdl,
              activeColor: AppColors.primary,
            ),
            const Divider(height: 0),
            SwitchListTile(
              title: const Text('Dark Theme'),
              value: settings.isDarkTheme,
              onChanged: settings.setDarkTheme,
              activeColor: AppColors.primary,
            ),
          ]),
          const SizedBox(height: 16),

          _sectionHeader('Data'),
          _card([
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.primary),
              title: const Text('Export History as CSV'),
              onTap: () => _exportCsv(context),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.delete_forever,
                  color: AppColors.error),
              title: const Text('Clear All History',
                  style: TextStyle(color: AppColors.error)),
              onTap: () => _confirmClearHistory(context),
            ),
          ]),
          const SizedBox(height: 32),

          const Text(
            'GlucoSense v1.0.0\nResearch prototype — not for medical diagnosis.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.primary,
          ),
        ),
      );

  Widget _card(List<Widget> children) =>
      Card(child: Column(children: children));

  void _editText(BuildContext context, String label, String current,
      void Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSave(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editDouble(
    BuildContext context,
    String label,
    double current,
    void Function(double) onSave, {
    required double min,
    required double max,
  }) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Value ($min – $max)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v >= min && v <= max) {
                onSave(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editInt(
    BuildContext context,
    String label,
    int current,
    void Function(int) onSave, {
    required int min,
    required int max,
  }) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: 'Value ($min – $max)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v >= min && v <= max) {
                onSave(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final appState = context.read<AppStateProvider>();
      final measurements = appState.measurements;
      final lines = [
        'id,timestamp,modelId,qualityPassed,predictedGlucose,referenceGlucose,'
        'correlation,bpm,spo2,pi,sdnn,drift,beats,clipping,samples',
        ...measurements.map((m) => [
              m.id,
              m.timestamp.toIso8601String(),
              m.modelId,
              m.qualityPassed,
              m.predictedGlucose ?? '',
              m.referenceGlucose ?? '',
              m.correlation,
              m.bpm,
              m.spo2,
              m.pi,
              m.sdnn,
              m.drift,
              m.beats,
              m.clipping,
              m.samples,
            ].join(',')),
      ];
      final csv = lines.join('\n');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/glucosense_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'GlucoSense Data Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'This will permanently delete all measurement history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppStateProvider>().clearAllHistory();
    }
  }
}

class _ThresholdTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ThresholdTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit,
              size: 16, color: AppColors.textSecondaryLight),
        ],
      ),
      onTap: onTap,
    );
  }
}
