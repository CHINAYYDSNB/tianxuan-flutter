import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan_flutter/services/metrics_service.dart';

void main() {
  group('parseCpu', () {
    test('parses total and idle', () {
      const line = 'cpu  292889 0 346812 1882344 13250 0 1359 0 0 0';
      final r = parseCpu(line);
      expect(r, isNotNull);
      expect(r!.idle, 1882344 + 13250);
      expect(r.total, 292889 + 346812 + 1882344 + 13250 + 1359);
    });

    test('rejects invalid', () {
      expect(parseCpu('cpu 123'), isNull);
      expect(parseCpu('cpux 1 2 3 4 5'), isNull);
    });
  });

  test('cpuPercent', () {
    expect(cpuPercent((total: 1000, idle: 900), (total: 2000, idle: 1400)),
        closeTo(50, 0.001));
    expect(cpuPercent((total: 100, idle: 50), (total: 100, idle: 50)), 0);
  });

  group('parseMem', () {
    const out = '              total        used        free\n'
        'Mem:           3948        1456        1240\n'
        'Swap:             0           0           0';
    test('parses total/used', () {
      final r = parseMem(out);
      expect(r!.total, 3948);
      expect(r.used, 1456);
    });
  });

  group('parseDiskstats', () {
    const out = '   8       0 sda 1000 0 2000 500 100 0 400 50 0 600 700 0\n'
        ' 252       0 dm-0 2000 0 4000 800 200 0 800 100 0 900 1100 0\n'
        '   7       0 loop0 1 0 1 1 0 0 0 0 0 1 1 0';
    test('skips virtual devices', () {
      final r = parseDiskstats(out);
      expect(r!.read, 2000);
      expect(r.write, 400);
    });
  });

  group('parseNetdev', () {
    const out = 'Inter-|   Receive\n'
        ' face |bytes\n'
        '    lo: 1000    10    0    0    0     0          0         0   1000    10    0    0    0     0       0          0\n'
        '  eth0: 5242880    512    0    0    0     0          0         0  1048576    128    0    0    0     0       0          0\n'
        ' ens3: 2621440    256    0    0    0     0          0         0  2097152    256    0    0    0     0       0          0';
    test('skips lo, sums rx/tx at positions 0 and 8', () {
      final r = parseNetdev(out);
      expect(r!.rx, 5242880 + 2621440);
      expect(r.tx, 1048576 + 2097152);
    });
  });

  test('kbpsDelta', () {
    expect(kbpsDelta(2048, 1024, 1.0), closeTo(1.0, 0.001));
    expect(kbpsDelta(100, 100, 1.0), 0);
  });

  test('parseMetricsText full pipeline', () {
    const out = '===STAT1===\n'
        'cpu  100 0 100 1000 0 0 0 0 0 0\n'
        '===DISK1===\n'
        '   8       0 sda 0 0 0 0 0 0 0 0 0 0 0 0\n'
        '===NET1===\n'
        'Inter-|   Receive\n'
        ' face |bytes\n'
        ' eth0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\n'
        '===STAT2===\n'
        'cpu  200 0 300 1100 0 0 0 0 0 0\n'
        '===DISK2===\n'
        '   8       0 sda 0 0 4096 0 0 0 2048 0 0 0 0 0\n'
        '===NET2===\n'
        'Inter-|   Receive\n'
        ' face |bytes\n'
        ' eth0: 2048 0 0 0 0 0 0 0 3072 0 0 0 0 0 0 0\n'
        '===MEM===\n'
        'Mem:           2000        1000\n'
        '===DISKFS===\n'
        'Filesystem      Size  Used Avail Use% Mounted on\n'
        '/dev/vda1        40G  8.2G   30G  22% /\n'
        '===UPTIME===\n'
        ' 01:24:15 up 5 days, load average: 0.10, 0.04, 0.01\n';

    final m = parseMetricsText(out);
    expect(m.online, isTrue);
    // cpu: total delta = (200+300+1100) - (100+100+1000) = 1600-1200=400; idle delta=100 -> 75%
    expect(m.cpuPercent, closeTo(75.0, 0.1));
    // io: 4096 sectors read -> 4096*0.5/0.5 = 4096 KB/s
    expect(m.ioReadKbps, closeTo(4096.0, 0.1));
    // net: rx delta 1048 bytes /1024/0.5 = ~2.047 KB/s
    expect(m.netRxKbps, closeTo(2.047, 0.1));
    expect(m.memTotalMb, 2000);
    expect(m.memUsedMb, 1000);
    expect(m.memPercent, closeTo(50.0, 0.1));
    expect(m.diskPercent, closeTo(22.0, 0.1));
    expect(m.load1, closeTo(0.10, 0.001));
  });
}
