/// Real-time data from LIVE:{json} lines, emitted every ~500ms.
class LiveData {
  final double timer; // seconds since finger placed (0.0 → ~25.0)
  final String phase; // "stabilizing" | "collecting"
  final int bpm;
  final int irAC; // signed IR AC component for waveform

  const LiveData({
    required this.timer,
    required this.phase,
    required this.bpm,
    required this.irAC,
  });

  bool get isCollecting => phase == 'collecting';
}
