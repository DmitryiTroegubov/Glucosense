import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/model_provider.dart';
import '../theme/colors.dart';
import '../widgets/model_card.dart';
import 'model_detail_screen.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModelProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import model',
            onPressed: () => _importModel(context, provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('New Model'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: provider.allModels.isEmpty
          ? _buildEmpty(context, provider)
          : ListView(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              children: provider.allModels
                  .map((model) => ModelCard(
                        model: model,
                        isActive: provider.activeModel.id == model.id,
                        onTap: () => provider.setActiveModel(model.id),
                        onInfo: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ModelDetailScreen(modelId: model.id),
                          ),
                        ),
                        onExport: () =>
                            _exportModel(context, provider, model.id),
                        onDelete: model.isDefault
                            ? null
                            : () => _confirmDelete(
                                context, provider, model.id),
                        onRename: model.isDefault
                            ? null
                            : () => _showRenameDialog(
                                context, provider, model.id, model.name),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, ModelProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline,
                size: 48, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            const Text(
              'No models yet',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + New Model to create a personal model calibrated to your physiology.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondaryLight, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('New Model'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, ModelProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Model'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Model name',
            hintText: 'e.g. Dmitriy',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await provider.createModel(name);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Model "$name" created')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ModelProvider provider,
      String modelId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Model'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await provider.renameModel(modelId, name);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportModel(BuildContext context, ModelProvider provider,
      String modelId) async {
    try {
      final json = await provider.exportModelJson(modelId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/glucosense_model_$modelId.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'GlucoSense Model Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importModel(
      BuildContext context, ModelProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final content =
          await File(result.files.single.path!).readAsString();
      final model = await provider.importModelJson(content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Model "${model.name}" imported')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, ModelProvider provider,
      String modelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model'),
        content: const Text(
            'This will permanently delete the model and all its calibration data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteModel(modelId);
    }
  }
}
