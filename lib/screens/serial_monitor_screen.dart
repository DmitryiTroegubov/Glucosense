import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class SerialMonitorScreen extends StatefulWidget {
  const SerialMonitorScreen({super.key});

  @override
  State<SerialMonitorScreen> createState() => _SerialMonitorScreenState();
}

class _SerialMonitorScreenState extends State<SerialMonitorScreen> {
  final ScrollController _scroll = ScrollController();
  bool _paused = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_paused && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final lines = appState.serialLog;
    final isConnected =
        appState.connectionStatus == BluetoothConnectionStatus.connected;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final textColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Monitor'),
        actions: [
          IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            tooltip: _paused ? 'Resume scroll' : 'Pause scroll',
            onPressed: () => setState(() => _paused = !_paused),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () => appState.clearSerialLog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color:
                isDark ? const Color(0xFF161B22) : const Color(0xFFEAECEF),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color:
                      isConnected ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected
                      ? 'Connected — ${lines.length} lines'
                      : 'Disconnected',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                if (_paused)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PAUSED',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: bg,
              child: lines.isEmpty
                  ? Center(
                      child: Text(
                        'No data yet...',
                        style: GoogleFonts.ibmPlexMono(
                          color: textColor.withOpacity(0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: lines.length,
                      itemBuilder: (_, i) => _SerialLine(
                        line: lines[i],
                        index: i,
                        textColor: textColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SerialLine extends StatelessWidget {
  final String line;
  final int index;
  final Color textColor;

  const _SerialLine({
    required this.line,
    required this.index,
    required this.textColor,
  });

  Color _lineColor(String line) {
    if (line.contains('LIVE:')) return const Color(0xFF34D399);
    if (line.contains('JSON:')) return const Color(0xFF60A5FA);
    if (line.contains('Finger Detected')) return AppColors.success;
    if (line.contains('NO FINGER') || line.contains('ERROR')) {
      return AppColors.error;
    }
    return textColor;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: textColor.withOpacity(0.3),
              ),
            ),
          ),
          Expanded(
            child: Text(
              line,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                color: _lineColor(line),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
