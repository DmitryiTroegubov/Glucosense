/// Overall app measurement state machine.
enum AppState {
  disconnected, // BT not connected
  idle,         // Connected, no finger detected
  stabilizing,  // Finger on sensor, 0–20s
  collecting,   // Collecting data, 20–25s
  result,       // JSON report received, showing prediction or rejection
}

/// Bluetooth connection status.
enum BluetoothConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
