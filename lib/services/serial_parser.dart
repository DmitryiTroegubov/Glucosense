import 'dart:convert';
import '../models/live_data.dart';
import '../models/report_data.dart';

// ─── Event hierarchy ──────────────────────────────────────────────────────────

sealed class ParsedEvent {}

class LiveDataEvent extends ParsedEvent {
  final LiveData data;
  LiveDataEvent(this.data);
}

class ReportEvent extends ParsedEvent {
  final ReportData data;
  ReportEvent(this.data);
}

class StatusEvent extends ParsedEvent {
  final StatusType type;
  StatusEvent(this.type);
}

class CsvLineEvent extends ParsedEvent {
  final String line;
  CsvLineEvent(this.line);
}

class RawLineEvent extends ParsedEvent {
  final String line;
  RawLineEvent(this.line);
}

enum StatusType {
  fingerDetected,
  noFinger,
  sensorError,
  notEnoughSamples,
  systemStart,
}

// ─── Parser ───────────────────────────────────────────────────────────────────

/// Stateless line-by-line parser. Call parseLine() for each complete line.
/// State management lives in AppStateProvider.
class SerialParser {
  /// Parse a single complete line from Bluetooth.
  /// Lines should already be trimmed of trailing \n/\r.
  ParsedEvent parseLine(String line) {
    final trimmed = line.trim();

    // 1. LIVE data
    if (trimmed.startsWith('LIVE:')) {
      try {
        final jsonStr = trimmed.substring(5);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return LiveDataEvent(LiveData(
          timer: (data['timer'] as num).toDouble(),
          phase: data['phase'] as String? ?? '',
          bpm: (data['bpm'] as num).toInt(),
          irAC: (data['irAC'] as num).toInt(),
        ));
      } catch (_) {
        return RawLineEvent(trimmed);
      }
    }

    // 2. JSON report (primary data source for predictions)
    if (trimmed.startsWith('JSON:')) {
      try {
        final jsonStr = trimmed.substring(5);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return ReportEvent(ReportData.fromJson(data, trimmed));
      } catch (_) {
        return RawLineEvent(trimmed);
      }
    }

    // 3. Status messages — matched as substrings
    if (trimmed.contains('Finger Detected')) {
      return StatusEvent(StatusType.fingerDetected);
    }
    if (trimmed.contains('NO FINGER DETECTED')) {
      return StatusEvent(StatusType.noFinger);
    }
    if (trimmed.contains('MAX30102 not found')) {
      return StatusEvent(StatusType.sensorError);
    }
    if (trimmed.contains('ERROR: Not enough samples')) {
      return StatusEvent(StatusType.notEnoughSamples);
    }
    if (trimmed.startsWith('System Start')) {
      return StatusEvent(StatusType.systemStart);
    }

    // 4. CSV copy line
    if (trimmed.startsWith('COPY THIS LINE') ||
        trimmed.startsWith('data.txt,') ||
        trimmed.startsWith('data 2.txt,')) {
      return CsvLineEvent(trimmed);
    }

    // 5. Everything else (report text block, separators, etc.)
    return RawLineEvent(trimmed);
  }
}
