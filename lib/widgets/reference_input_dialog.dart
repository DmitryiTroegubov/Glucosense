import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Bottom sheet for entering a reference blood glucose value (mmol/L).
/// Validates 1.0 – 35.0 mmol/L before calling [onSave].
Future<void> showReferenceInputDialog(
  BuildContext context, {
  required Future<void> Function(double mmol) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReferenceInputSheet(onSave: onSave),
  );
}

class _ReferenceInputSheet extends StatefulWidget {
  final Future<void> Function(double mmol) onSave;
  const _ReferenceInputSheet({required this.onSave});

  @override
  State<_ReferenceInputSheet> createState() => _ReferenceInputSheetState();
}

class _ReferenceInputSheetState extends State<_ReferenceInputSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String v) {
    final parsed = double.tryParse(v);
    setState(() {
      if (parsed == null) {
        _error = 'Enter a valid number';
      } else if (parsed < 1.0 || parsed > 35.0) {
        _error = 'Must be between 1.0 and 35.0 mmol/L';
      } else {
        _error = null;
      }
    });
  }

  Future<void> _submit() async {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 1.0 || parsed > 35.0) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(parsed);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Reference Glucose',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your fingerstick reading to calibrate the model.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Blood Glucose (mmol/L)',
              hintText: 'e.g. 5.5',
              suffix: const Text('mmol/L'),
              errorText: _error,
            ),
            onChanged: _validate,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_error == null && _controller.text.isNotEmpty && !_saving)
                          ? _submit
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
