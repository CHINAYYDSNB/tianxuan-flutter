import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RecordingEvent {
  final int timeMs;
  final List<int> data;

  RecordingEvent({required this.timeMs, required this.data});

  Map<String, dynamic> toJson() => {'t': timeMs, 'd': base64Encode(data)};

  factory RecordingEvent.fromJson(Map<String, dynamic> json) =>
      RecordingEvent(
        timeMs: json['t'] as int,
        data: base64Decode(json['d'] as String),
      );
}

class RecordingSession {
  final String hostName;
  final DateTime startedAt;
  final int durationMs;
  final List<RecordingEvent> events;

  RecordingSession({
    required this.hostName,
    required this.startedAt,
    required this.durationMs,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'hostName': hostName,
        'startedAt': startedAt.toIso8601String(),
        'durationMs': durationMs,
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory RecordingSession.fromJson(Map<String, dynamic> json) =>
      RecordingSession(
        hostName: json['hostName'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        durationMs: json['durationMs'] as int,
        events: (json['events'] as List)
            .map((e) => RecordingEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Records terminal output (with timestamps) during an SSH session for later
/// in-app replay. Not a screen recording - only the terminal data stream.
class RecordingService {
  final List<RecordingEvent> _events = [];
  DateTime? _startedAt;
  String _hostName = '';
  bool _recording = false;

  bool get isRecording => _recording;

  String get hostName => _hostName;

  int get elapsedMs {
    final s = _startedAt;
    if (s == null) return 0;
    return DateTime.now().difference(s).inMilliseconds;
  }

  void start(String hostName) {
    _events.clear();
    _startedAt = DateTime.now();
    _hostName = hostName;
    _recording = true;
  }

  void record(List<int> bytes) {
    if (!_recording || bytes.isEmpty) return;
    final now = DateTime.now();
    final base = _startedAt ?? now;
    _events.add(RecordingEvent(
      timeMs: now.difference(base).inMilliseconds,
      data: List<int>.from(bytes),
    ));
  }

  RecordingSession stop() {
    _recording = false;
    final duration = DateTime.now().difference(_startedAt ?? DateTime.now());
    return RecordingSession(
      hostName: _hostName,
      startedAt: _startedAt ?? DateTime.now(),
      durationMs: duration.inMilliseconds,
      events: List<RecordingEvent>.from(_events),
    );
  }

  static Directory? baseDirOverride;

  static Future<Directory> recordingsDir() async {
    if (baseDirOverride != null) {
      if (!baseDirOverride!.existsSync()) {
        baseDirOverride!.createSync(recursive: true);
      }
      return baseDirOverride!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}Tianxuan${Platform.pathSeparator}录像');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static String _safeName(String s) {
    final buf = StringBuffer();
    for (final c in s.codeUnits) {
      if (c >= 48 && c <= 57 ||
          c >= 65 && c <= 90 ||
          c >= 97 && c <= 122 ||
          c == 45 ||
          c == 95 ||
          c == 46) {
        buf.writeCharCode(c);
      } else {
        buf.write('_');
      }
    }
    return buf.toString().isEmpty ? 'session' : buf.toString();
  }

  static Future<File> save(RecordingSession session) async {
    final dir = await recordingsDir();
    final ts = session.startedAt
        .toLocal()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.').first;
    final file = File('${dir.path}${Platform.pathSeparator}${_safeName(session.hostName)}-$ts.json');
    await file.writeAsString(jsonEncode(session.toJson()));
    return file;
  }

  static Future<List<File>> list() async {
    final dir = await recordingsDir();
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  static Future<RecordingSession> load(File file) async {
    final raw = await file.readAsString();
    return RecordingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> delete(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
