import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Global logging service. All modules write to `./logs/` (one file per day).
/// Log lines are written synchronously with an internal buffer flushed to disk
/// periodically so it is safe to call from any isolate/task.
class LogService {
  LogService._();

  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._();

  static Directory? _dirOverride;

  IOSink? _sink;
  File? _currentFile;
  String _today = '';
  final List<String> _pending = [];
  Timer? _flushTimer;

  /// Allow tests to redirect the log directory.
  static void setDirOverride(Directory dir) {
    _dirOverride = dir;
  }

  /// Force a fresh log file (used by tests between cases).
  void reset() {
    _flushTimer?.cancel();
    _flush();
    _sink?.close();
    _sink = null;
    _currentFile = null;
    _today = '';
    _pending.clear();
  }
  Directory get logsDir {
    final base = _dirOverride ??
        Directory('${Directory.current.path}${Platform.pathSeparator}logs');
    if (!base.existsSync()) {
      base.createSync(recursive: true);
    }
    return base;
  }

  void init() {
    try {
      _rollIfNeeded();
      _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) => _flush());
      _log('log', 'INFO', 'LogService initialized, dir=${logsDir.path}');
    } catch (e) {
      // never let logging failure break the app
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void _rollIfNeeded() {
    final key = _todayKey();
    if (_currentFile != null && key == _today) return;
    _flush();
    _today = key;
    _currentFile = File('${logsDir.path}${Platform.pathSeparator}app-$key.log');
    _sink = _currentFile!.openWrite(mode: FileMode.append);
  }

  void _log(String category, String level, String message) {
    try {
      _rollIfNeeded();
      final now = DateTime.now();
      final ts = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}.'
          '${now.millisecond.toString().padLeft(3, '0')}';
      _pending.add('[$ts] [$level] [$category] $message');
      if (_pending.length >= 100) {
        _flush();
      }
    } catch (_) {}
  }

  void _flush() {
    if (_pending.isEmpty || _sink == null) return;
    try {
      final lines = '${_pending.join('\n')}\n';
      _pending.clear();
      _sink!.write(lines);
    } catch (_) {}
  }

  void info(String category, String message) =>
      _log(category, 'INFO', message);

  void warn(String category, String message) =>
      _log(category, 'WARN', message);

  void error(String category, String message) =>
      _log(category, 'ERROR', message);

  /// Write raw terminal bytes in a readable form.
  /// - printable ASCII shown as-is
  /// - control sequences shown as \x1b[... etc
  /// - non-ASCII shown as \uXXXX
  void writeBytes(String category, List<int> bytes, {String prefix = ''}) {
    final sb = StringBuffer(prefix);
    for (final b in bytes) {
      if (b == 0x1b) {
        sb.write('\\x1b');
      } else if (b == 0x0d) {
        sb.write('\\r');
      } else if (b == 0x0a) {
        sb.write('\\n');
      } else if (b == 0x09) {
        sb.write('\\t');
      } else if (b >= 0x20 && b < 0x7f) {
        sb.writeCharCode(b);
      } else {
        sb.write('\\u${b.toRadixString(16).padLeft(2, '0')}');
      }
    }
    _log(category, 'BYTES', sb.toString());
  }

  List<File> listLogs() {
    if (!logsDir.existsSync()) return [];
    return logsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  File? get todayFile => _currentFile;

  Future<String> readToday() async {
    _flush();
    final f = _currentFile;
    if (f == null || !f.existsSync()) return '';
    try {
      await _sink?.flush();
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<void> clearToday() async {
    _flush();
    final f = _currentFile;
    if (f != null && f.existsSync()) {
      try {
        await _sink?.flush();
        await f.writeAsString('');
      } catch (_) {}
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush();
    _sink?.close();
    _sink = null;
    _currentFile = null;
  }

  /// Readable display of a UTF-8 byte list (for logging user input).
  static String utf8Display(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
}
