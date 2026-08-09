import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/host.dart';

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
  }) async {
    await disconnect();

    final socket = await SSHSocket.connect(host.address, host.port,
        timeout: const Duration(seconds: 15));
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

    onStateChange?.call(true);
  }

  Future<void> startShell({int cols = 80, int rows = 24}) async {
    if (_client == null) return;
    _shell = await _client!.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: cols,
        height: rows,
      ),
    );

    _subs.add(_shell!.stdout.listen((data) {
      if (!_disposed) onOutput?.call(data);
    }));
    _subs.add(_shell!.stderr.listen((data) {
      if (!_disposed) onOutput?.call(data);
    }));
    _shell!.done.then((_) {
      if (!_disposed) {
        onStateChange?.call(false);
      }
    }).catchError((Object _) {
      if (!_disposed) {
        onStateChange?.call(false);
      }
    });
  }

  void write(String data) {
    _shell?.write(utf8Bytes(data));
  }

  void writeBytes(List<int> bytes) {
    _shell?.write(Uint8List.fromList(bytes));
  }

  Future<void> resize(int cols, int rows) async {
    try {
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
