import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_service.dart';

class SftpEntry {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final int mode;
  final DateTime? modified;

  SftpEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.mode,
    this.modified,
  });
}

class SftpService {
  SftpClient? _sftp;

  bool get isReady => _sftp != null;

  Future<void> init(SshService ssh) async {
    final client = ssh.client;
    if (client == null) throw StateError('ssh not connected');
    _sftp = await client.sftp();
  }

  Future<List<SftpEntry>> list(String path) async {
    final fs = _require();
    final names = await fs.listdir(path);
    final entries = <SftpEntry>[];
    for (final name in names) {
      if (name.filename == '.' || name.filename == '..') continue;
      final full = path == '/' ? '/${name.filename}' : '$path/${name.filename}';
      final attrs = name.attr;
      entries.add(SftpEntry(
        name: name.filename,
        path: full,
        isDir: attrs.isDirectory,
        size: attrs.size ?? 0,
        mode: attrs.mode?.value ?? 0,
        modified: attrs.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
            : null,
      ));
    }
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<void> upload(String localPath, String remotePath) async {
    final fs = _require();
    final file = await fs.open(remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write);
    try {
      final bytes = await File(localPath).readAsBytes();
      await file.writeBytes(Uint8List.fromList(bytes));
      await file.close();
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  Future<void> download(String remotePath, String localPath) async {
    final fs = _require();
    final file = await fs.open(remotePath, mode: SftpFileOpenMode.read);
    try {
      final bytes = await file.readBytes();
      await File(localPath).writeAsBytes(bytes);
    } finally {
      await file.close();
    }
  }

  Future<String> readText(String path) async {
    final fs = _require();
    final file = await fs.open(path, mode: SftpFileOpenMode.read);
    try {
      final bytes = await file.readBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await file.close();
    }
  }

  Future<void> writeText(String path, String content) async {
    final fs = _require();
    final file = await fs.open(path,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write);
    try {
      await file.writeBytes(Uint8List.fromList(content.codeUnits));
      await file.close();
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  Future<void> remove(String path, {required bool isDir}) async {
    final fs = _require();
    if (isDir) {
      await fs.rmdir(path);
    } else {
      await fs.remove(path);
    }
  }

  Future<void> rename(String oldPath, String newPath) async {
    final fs = _require();
    await fs.rename(oldPath, newPath);
  }

  Future<SftpFileAttrs> stat(String path) async {
    final fs = _require();
    return fs.stat(path);
  }

  SftpClient _require() {
    final fs = _sftp;
    if (fs == null) throw StateError('sftp not initialized');
    return fs;
  }
}
