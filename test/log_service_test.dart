import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan_flutter/services/log_service.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tx_log_test');
    LogService.setDirOverride(tmpDir);
    LogService.instance.reset();
  });

  tearDown(() async {
    LogService.instance.dispose();
    // give close() a moment to release the file handle
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('logs to ./logs dir and reads back', () async {
    final log = LogService.instance;
    log.init();
    log.info('ssh', 'connect start');
    log.error('ws', 'boom');
    log.writeBytes('ssh-in', [104, 105, 13], prefix: 'write> ');

    final text = await log.readToday();
    expect(text, contains('[INFO] [ssh] connect start'));
    expect(text, contains('[ERROR] [ws] boom'));
    expect(text, contains('write> hi\\r'));

    final files = log.listLogs();
    expect(files, isNotEmpty);
    expect(files.first.path, startsWith(tmpDir.path));
  });

  test('writeBytes renders control and non-ascii', () async {
    final log = LogService.instance;
    log.init();
    // 0x1b ESC, 0x0a LF, byte 0xe4 (non-ascii utf8 lead)
    log.writeBytes('ssh-out', [0x1b, 0x5b, 0x31, 0x6d, 0x0a, 0xe4]);
    final text = await log.readToday();
    expect(text, contains('\\x1b[1m'));
    expect(text, contains('\\n'));
    expect(text, contains('\\ue4'));
  });
}
