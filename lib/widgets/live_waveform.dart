import 'package:flutter/material.dart';

/// Scrolling IR_AC waveform using CustomPainter.
/// Shows heartbeat pulses during STABILIZING and COLLECTING phases.
class LiveWaveform extends StatelessWidget {
  final List<int> buffer; // rolling irAC values
  final Color color;

  const LiveWaveform({
    super.key,
    required this.buffer,
    this.color = const Color(0xFF0D9488),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 80),
      painter: _WaveformPainter(buffer: buffer, color: color),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> buffer;
  final Color color;

  _WaveformPainter({required this.buffer, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Normalize values to [0, 1]
    final minVal = buffer.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = buffer.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxVal - minVal).abs();
    final normalize = range < 1 ? 1.0 : range;

    final path = Path();
    final stepX = size.width / (buffer.length - 1);

    for (int i = 0; i < buffer.length; i++) {
      final x = i * stepX;
      // Invert y so larger values appear higher
      final normalized = (buffer[i] - minVal) / normalize;
      final y = size.height - (normalized * size.height * 0.85 + size.height * 0.075);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.buffer != buffer || old.buffer.length != buffer.length;
}
