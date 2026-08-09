import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/host.dart';
import 'log_service.dart';

class SshService {
  SSHClient? _client;
  SSHSession? _shell;
  final List<StreamSubscription> _subs = [];
  bool _disposed = false;

  bool get isConnected => _client != null;

  SSHClient? get client => _client;

  void Function(List<int> bytes)? onOutput;
  void Function(bool connected)? onStateChange;
  void Function(String error)? onError;

  Future<void> connect({
    required Host host,
    required String? password,
    String? privateKey,
    bool logVerbose = true,
  }) async {
    final log = LogService.instance;
    if (logVerbose) {
      log.info('ssh', 'connect start host=${host.address} port=${host.port} '
          'user=${host.username} hasKey=${privateKey != null && privateKey.isNotEmpty}');
    }
    final sw = Stopwatch()..start();
    await disconnect();

    try {
      final socket = await SSHSocket.connect(host.address, host.port,
          timeout: const Duration(seconds: 15));
      if (logVerbose) {
        log.info('ssh', 'tcp connected in ${sw.elapsedMilliseconds}ms');
      }
      _client = SSHClient(
        socket,
        username: host.username,
        onPasswordRequest: () => password ?? '',
        identities: [
          if (privateKey != null && privateKey.isNotEmpty)
            ...SSHKeyPair.fromPem(privateKey),
        ],
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 15),
      );
      await _client!.authenticated;
      if (logVerbose) {
        log.info('ssh', 'authenticated in ${sw.elapsedMilliseconds}ms '
            'remote=${_client!.remoteVersion}');
      }

      onStateChange?.call(true);
    } catch (e) {
      log.error('ssh', 'connect failed after ${sw.elapsedMilliseconds}ms: $e');
      onError?.call('$e');
      rethrow;
    }
  }

  Future<void> startShell({int cols = 80, int rows = 24}) async {
    final log = LogService.instance;
    if (_client == null) {
      log.warn('ssh', 'startShell called but client is null');
      return;
    }
    log.info('ssh', 'startShell pty=$cols x $rows');
    _shell = await _client!.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: cols,
        height: rows,
      ),
    );
    log.info('ssh', 'shell opened');

    _subs.add(_shell!.stdout.listen((data) {
      if (!_disposed) {
        log.writeBytes('ssh-out', data, prefix: 'stdout> ');
        onOutput?.call(data);
      }
    }));
    _subs.add(_shell!.stderr.listen((data) {
      if (!_disposed) {
        log.writeBytes('ssh-out', data, prefix: 'stderr> ');
        onOutput?.call(data);
      }
    }));
    _shell!.done.then((_) {
      log.info('ssh', 'shell done');
      if (!_disposed) {
        onStateChange?.call(false);
      }
    }).catchError((Object e) {
      log.warn('ssh', 'shell error: $e');
      if (!_disposed) {
        onStateChange?.call(false);
      }
    });
  }

  void write(String data) {
    final bytes = utf8.encode(data);
    LogService.instance.writeBytes('ssh-in', bytes, prefix: 'write> ');
    _shell?.write(Uint8List.fromList(bytes));
  }

  void writeBytes(List<int> bytes) {
    LogService.instance.writeBytes('ssh-in', bytes, prefix: 'writeBytes> ');
    _shell?.write(Uint8List.fromList(bytes));
  }

  Future<void> resize(int cols, int rows) async {
    try {
      LogService.instance.info('ssh', 'resize $cols x $rows');
      _shell?.resizeTerminal(cols, rows);
    } catch (_) {}
  }

  Future<SSHSession> execute(String command) async {
    if (_client == null) {
      throw StateError('not connected');
    }
    return _client!.execute(command);
  }

  Future<Uint8List> run(String command) async {
    if (_client == null) {
      throw StateError('not connected');
    }
    return _client!.run(command);
  }

  Future<void> disconnect() async {
    LogService.instance.info('ssh', 'disconnect');
    _disposed = false;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _shell = null;
    _client?.close();
    _client = null;
  }

  void dispose() {
    _disposed = true;
  }

  static Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

  static Future<void> testConnection({
    required Host host,
    String? password,
  }) async {
    final svc = SshService();
    await svc.connect(host: host, password: password);
    final out = await svc.run('echo tianxuan-pong');
    if (String.fromCharCodes(out).trim() != 'tianxuan-pong') {
      throw StateError('unexpected echo');
    }
    await svc.disconnect();
  }
}
