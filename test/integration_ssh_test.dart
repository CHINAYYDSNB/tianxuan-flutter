import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan_flutter/models/host.dart';
import 'package:tianxuan_flutter/services/metrics_service.dart';
import 'package:tianxuan_flutter/services/sftp_service.dart';
import 'package:tianxuan_flutter/services/ssh_service.dart';

String? _env(String key) => Platform.environment[key];

Host _testHost() {
  return Host.create(
    name: 'CI Test',
    address: _env('TX_TEST_HOST') ?? '47.100.33.169',
    port: int.parse(_env('TX_TEST_PORT') ?? '22'),
    username: _env('TX_TEST_USER') ?? 'root',
    authType: AuthType.password,
    group: '默认',
    tags: const [],
  );
}

void main() {
  final password = _env('TX_TEST_PASSWORD');

  group('ssh integration', () {
    test('connect and run echo', () async {
      if (password == null) {
        markTestSkipped('TX_TEST_PASSWORD not set');
        return;
      }
      final ssh = SshService();
      await ssh.connect(host: _testHost(), password: password);
      final out = await ssh.run('echo tianxuan-pong');
      expect(String.fromCharCodes(out).trim(), 'tianxuan-pong');
      await ssh.disconnect();
    });

    test('collect metrics from real server', () async {
      if (password == null) {
        markTestSkipped('TX_TEST_PASSWORD not set');
        return;
      }
      final ssh = SshService();
      await ssh.connect(host: _testHost(), password: password);
      final m = await collectMetrics(ssh);
      expect(m.online, isTrue);
      expect(m.memTotalMb, greaterThan(0));
      expect(m.cpuPercent, inInclusiveRange(0, 100));
      expect(m.diskTotalGb, greaterThan(0));
      await ssh.disconnect();
    });

    test('sftp list root', () async {
      if (password == null) {
        markTestSkipped('TX_TEST_PASSWORD not set');
        return;
      }
      final ssh = SshService();
      await ssh.connect(host: _testHost(), password: password);
      final sftp = SftpService();
      await sftp.init(ssh);
      final entries = await sftp.list('/root');
      expect(entries, isNotEmpty);
      await ssh.disconnect();
    });

    test('sftp write/read/rename/delete roundtrip', () async {
      if (password == null) {
        markTestSkipped('TX_TEST_PASSWORD not set');
        return;
      }
      final ssh = SshService();
      await ssh.connect(host: _testHost(), password: password);
      final sftp = SftpService();
      await sftp.init(ssh);

      final path = '/tmp/tianxuan_flutter_test.txt';
      await sftp.writeText(path, 'hello flutter sftp');
      final content = await sftp.readText(path);
      expect(content, 'hello flutter sftp');

      final renamed = '$path.renamed';
      await sftp.rename(path, renamed);
      expect(await sftp.readText(renamed), 'hello flutter sftp');

      await sftp.remove(renamed, isDir: false);
      await ssh.disconnect();
    });
  });
}
