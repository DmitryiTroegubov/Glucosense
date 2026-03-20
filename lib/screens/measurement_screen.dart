import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/enums.dart';
import '../providers/app_state.dart';
import '../providers/model_provider.dart';
import '../providers/settings_provider.dart';
import '../services/prediction_service.dart';
import '../theme/colors.dart';
import '../widgets/live_waveform.dart';
import '../widgets/metric_card.dart';
import '../widgets/phase_progress.dart';
import '../widgets/quality_failure_list.dart';
import '../widgets/reference_input_dialog.dart';
import 'ble_connect_screen.dart';

class MeasurementScreen extends StatelessWidget {
  const MeasurementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final modelProvider = context.watch<ModelProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: Column(
        children: [
          _BtBar(appState: appState),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildBody(context, appState, modelProvider, settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppStateProvider appState,
    ModelProvider modelProvider,
    SettingsProvider settings,
  ) {
    switch (appState.measurementState) {
      case AppState.disconnected:
        return _Centered(
          key: const ValueKey('disconnected'),
          icon: Icons.bluetooth_disabled,
          iconColor: AppColors.primary,
          title: 'Not connected',
          subtitle: 'Connect to your GlucoSense device to start measuring',
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BleConnectScreen()),
              ),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48)),
            ),
          ),
        );

      case AppState.idle:
        return _Centered(
          key: const ValueKey('idle'),
          icon: Icons.fingerprint,
          iconColor: AppColors.primary,
          title: 'Place your finger on the sensor',
          subtitle: 'Hold still — the device will detect your finger automatically',
          pulse: true,
        );

      case AppState.stabilizing:
        final timer = appState.liveData?.timer ?? 0.0;
        final progress =
            (timer / AppConstants.stabilizationSeconds).clamp(0.0, 1.0);
        final remaining =
            (AppConstants.stabilizationSeconds - timer).ceil().clamp(0, AppConstants.stabilizationSeconds);
        final bpm = appState.liveData?.bpm ?? 0;

        return _PhaseView(
          key: const ValueKey('stabilizing'),
          progress: progress,
          remainingSeconds: remaining,
          label: 'Stabilizing...',
          color: AppColors.primary,
          bpm: bpm,
          irACBuffer: appState.irACBuffer,
        );

      case AppState.collecting:
        final timer = appState.liveData?.timer ?? AppConstants.stabilizationSeconds.toDouble();
        final elapsed =
            (timer - AppConstants.stabilizationSeconds).clamp(0.0, AppConstants.collectionSeconds.toDouble());
        final progress =
            (elapsed / AppConstants.collectionSeconds).clamp(0.0, 1.0);
        final remaining =
            (AppConstants.collectionSeconds - elapsed).ceil().clamp(0, AppConstants.collectionSeconds);
        final bpm = appState.liveData?.bpm ?? 0;

        return _PhaseView(
          key: const ValueKey('collecting'),
          progress: progress,
          remainingSeconds: remaining,
          label: 'Collecting data...',
          color: AppColors.warning,
          bpm: bpm,
          irACBuffer: appState.irACBuffer,
        );

      case AppState.result:
        final quality = appState.currentQuality;
        final report = appState.currentReport;

        if (quality != null && quality.passed && report != null) {
          // Predict with active model
          final glucose =
              PredictionService.predict(modelProvider.activeModel, report);
          return _ResultView(
            key: const ValueKey('result_passed'),
            glucose: glucose,
            report: report,
            useMgdl: settings.useMgdl,
            onSaveCalibration: () => showReferenceInputDialog(
              context,
              onSave: (mmol) => appState.saveToCalibration(mmol, modelProvider),
            ),
            onDismiss: appState.dismissResult,
          );
        }

        return _RejectedView(
          key: const ValueKey('result_rejected'),
          failures: quality?.failures ?? [],
          onDismiss: appState.dismissResult,
        );
    }
  }
}

// ─── BT status bar ───────────────────────────────────────────────────────────

class _BtBar extends StatelessWidget {
  final AppStateProvider appState;
  const _BtBar({required this.appState});

  @override
  Widget build(BuildContext context) {
    final status = appState.connectionStatus;
    final deviceName = appState.connectedDevice?.name ?? 'Not connected';

    Color color;
    IconData icon;
    String label;

    switch (status) {
      case BluetoothConnectionStatus.connected:
        color = AppColors.success;
        icon = Icons.bluetooth_connected;
        label = deviceName;
        break;
      case BluetoothConnectionStatus.connecting:
        color = AppColors.warning;
        icon = Icons.bluetooth_searching;
        label = 'Connecting...';
        break;
      case BluetoothConnectionStatus.reconnecting:
        color = AppColors.warning;
        icon = Icons.bluetooth_searching;
        label = 'Reconnecting...';
        break;
      case BluetoothConnectionStatus.disconnected:
        color = AppColors.error;
        icon = Icons.bluetooth_disabled;
        label = 'Disconnected';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Centered state (disconnected / idle) ────────────────────────────────────

class _Centered extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool pulse;
  final Widget? child;

  const _Centered({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.pulse = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withOpacity(0.1),
      ),
      child: Icon(icon, size: 48, color: iconColor),
    );
    if (pulse) iconWidget = _PulseRing(child: iconWidget);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondaryLight, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

// ─── Phase view (stabilizing / collecting) ────────────────────────────────────

class _PhaseView extends StatelessWidget {
  final double progress;
  final int remainingSeconds;
  final String label;
  final Color color;
  final int bpm;
  final List<int> irACBuffer;

  const _PhaseView({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    required this.label,
    required this.color,
    required this.bpm,
    required this.irACBuffer,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          PhaseProgress(
            value: progress,
            color: color,
            remainingSeconds: remainingSeconds,
            label: label,
          ),
          const SizedBox(height: 32),
          if (bpm > 0)
            MetricCard(
              label: 'BPM',
              value: bpm.toString(),
              valueColor: color,
            ),
          const SizedBox(height: 24),
          if (irACBuffer.length >= 2) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: LiveWaveform(
                buffer: irACBuffer,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Result view (passed) ─────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final double? glucose;
  final dynamic report;
  final bool useMgdl;
  final VoidCallback onSaveCalibration;
  final VoidCallback onDismiss;

  const _ResultView({
    super.key,
    required this.glucose,
    required this.report,
    required this.useMgdl,
    required this.onSaveCalibration,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    double? glucoseDisplay;
    if (glucose != null) {
      glucoseDisplay = useMgdl ? glucose! * AppConstants.mmolToMgdl : glucose!;
    }

    String glucoseStr;
    Color glucoseColor;
    if (glucoseDisplay == null) {
      glucoseStr = '—';
      glucoseColor = secondaryColor;
    } else {
      glucoseStr = useMgdl
          ? glucoseDisplay.toStringAsFixed(0)
          : glucoseDisplay.toStringAsFixed(1);
      final mmol = glucose!;
      if (mmol < 3.9) {
        glucoseColor = AppColors.error;
      } else if (mmol > 7.8) {
        glucoseColor = AppColors.warning;
      } else {
        glucoseColor = AppColors.accent;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
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
                glucoseStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: glucoseColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 8),
                child: Text(
                  useMgdl ? 'mg/dL' : 'mmol/L',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    color: secondaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.qualityGood.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              report.correlation >= 0.85 ? 'Good quality' : 'Fair quality',
              style: const TextStyle(
                color: AppColors.qualityGood,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              MetricCard(
                  label: 'BPM', value: report.bpm.toStringAsFixed(0)),
              MetricCard(
                  label: 'SpO₂',
                  value: '${report.spo2.toStringAsFixed(1)}%'),
              MetricCard(
                  label: 'PI',
                  value: report.pi.toStringAsFixed(2)),
              MetricCard(
                  label: 'CORR',
                  value: report.correlation.toStringAsFixed(3)),
              MetricCard(
                  label: 'SDNN',
                  value: report.sdnn.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onSaveCalibration,
              icon: const Icon(Icons.bloodtype),
              label: const Text('Save to Calibration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onDismiss,
              icon: const Icon(Icons.check),
              label: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Result view (rejected) ───────────────────────────────────────────────────

class _RejectedView extends StatelessWidget {
  final List<String> failures;
  final VoidCallback onDismiss;

  const _RejectedView({
    super.key,
    required this.failures,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          const Icon(Icons.warning_rounded,
              size: 80, color: AppColors.warning),
          const SizedBox(height: 16),
          const Text(
            'Measurement rejected',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saved to history. Place your finger again for a new reading.',
            style: TextStyle(
                color: AppColors.textSecondaryLight, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          QualityFailureList(failures: failures),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onDismiss,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulse ring animation ─────────────────────────────────────────────────────

class _PulseRing extends StatefulWidget {
  final Widget child;
  const _PulseRing({required this.child});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.4, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(_opacity.value),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}
