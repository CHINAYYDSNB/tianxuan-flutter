import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan_flutter/services/recording_service.dart';

void main() {
  group('RecordingEvent', () {
    test('json roundtrip', () {
      final e = RecordingEvent(timeMs: 123, data: [27, 91, 49, 109, 104, 105]);
      final back = RecordingEvent.fromJson(e.toJson());
      expect(back.timeMs, 123);
      expect(back.data, [27, 91, 49, 109, 104, 105]);
    });
  });

  group('RecordingSession', () {
    test('json roundtrip', () {
      final s = RecordingSession(
        hostName: 'prod',
        startedAt: DateTime.utc(2026, 1, 1),
        durationMs: 5000,
        events: [
          RecordingEvent(timeMs: 0, data: utf8.encode('hello')),
          RecordingEvent(timeMs: 1200, data: utf8.encode('\r\n\$ ')),
        ],
      );
      final back = RecordingSession.fromJson(s.toJson());
      expect(back.hostName, 'prod');
      expect(back.durationMs, 5000);
      expect(back.events.length, 2);
      expect(String.fromCharCodes(back.events[1].data), '\r\n\$ ');
    });
  });

  group('RecordingService', () {
    test('record collects events with timestamps', () async {
      final svc = RecordingService();
      svc.start('test-host');
      svc.record([97, 98, 99]); // abc
      await Future<void>.delayed(const Duration(milliseconds: 30));
      svc.record([100]); // d
      final session = svc.stop();
      expect(svc.isRecording, isFalse);
      expect(session.hostName, 'test-host');
      expect(session.events.length, 2);
      expect(String.fromCharCodes(session.events[0].data), 'abc');
      // second event time should be >= first
      expect(session.events[1].timeMs, greaterThanOrEqualTo(session.events[0].timeMs));
      expect(session.durationMs, greaterThanOrEqualTo(30));
    });

    test('save + load + list + delete roundtrip', () async {
      RecordingService.baseDirOverride =
          Directory.systemTemp.createTempSync('tx_rec_test');
      addTearDown(() => RecordingService.baseDirOverride!.deleteSync(recursive: true));

      final svc = RecordingService();
      svc.start('test-host');
      svc.record(utf8.encode('ls -la\r\n'));
      final session = svc.stop();

      final dir = await RecordingService.recordingsDir();
      final before = await RecordingService.list();
      final file = await RecordingService.save(session);
      expect(file.existsSync(), isTrue);
      expect(file.path, startsWith(dir.path));

      final after = await RecordingService.list();
      expect(after.length, before.length + 1);

      final loaded = await RecordingService.load(file);
      expect(loaded.hostName, 'test-host');
      expect(String.fromCharCodes(loaded.events.single.data), 'ls -la\r\n');

      await RecordingService.delete(file);
      expect(file.existsSync(), isFalse);
    });

    test('recording ignored when not started', () {
      final svc = RecordingService();
      svc.record([1, 2, 3]);
      final session = svc.stop();
      expect(session.events, isEmpty);
    });
  });
}
