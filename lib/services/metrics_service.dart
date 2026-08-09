import '../services/ssh_service.dart';

class HostMetrics {
  double cpuPercent;
  int memTotalMb;
  int memUsedMb;
  double memPercent;
  double diskTotalGb;
  double diskUsedGb;
  double diskPercent;
  double load1;
  double load5;
  double load15;
  double ioReadKbps;
  double ioWriteKbps;
  double netRxKbps;
  double netTxKbps;
  bool online;

  HostMetrics({
    this.cpuPercent = 0,
    this.memTotalMb = 0,
    this.memUsedMb = 0,
    this.memPercent = 0,
    this.diskTotalGb = 0,
    this.diskUsedGb = 0,
    this.diskPercent = 0,
    this.load1 = 0,
    this.load5 = 0,
    this.load15 = 0,
    this.ioReadKbps = 0,
    this.ioWriteKbps = 0,
    this.netRxKbps = 0,
    this.netTxKbps = 0,
    this.online = true,
  });

  factory HostMetrics.offline() => HostMetrics(online: false);
}

/// Parse a single `/proc/stat` first line into (total, idle) jiffies.
({int total, int idle})? parseCpu(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts[0] != 'cpu' || parts.length < 5) return null;
  var total = 0;
  var idle = 0;
  for (var i = 1; i < parts.length; i++) {
    final v = int.tryParse(parts[i]);
    if (v == null) return null;
    total += v;
    if (i == 4 || i == 5) idle += v;
  }
  return (total: total, idle: idle);
}

double cpuPercent(({int total, int idle}) a, ({int total, int idle}) b) {
  final dTotal = b.total - a.total;
  if (dTotal <= 0) return 0;
  final dIdle = b.idle - a.idle;
  return (dTotal - dIdle) / dTotal * 100;
}

/// Parse `free -m` into (total, used).
({int total, int used})? parseMem(String out) {
  for (final line in out.split('\n')) {
    if (line.startsWith('Mem:')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        return (total: int.tryParse(parts[1]) ?? 0, used: int.tryParse(parts[2]) ?? 0);
      }
    }
  }
  return null;
}

double parseSize(String s) {
  final t = s.trim();
  if (t.endsWith('G')) return double.tryParse(t.substring(0, t.length - 1)) ?? 0;
  if (t.endsWith('M')) {
    return (double.tryParse(t.substring(0, t.length - 1)) ?? 0) / 1024;
  }
  if (t.endsWith('T')) {
    return (double.tryParse(t.substring(0, t.length - 1)) ?? 0) * 1024;
  }
  return double.tryParse(t) ?? 0;
}

({double total, double used, double percent})? parseDf(String out, String mount) {
  final lines = out.split('\n');
  for (var i = 1; i < lines.length; i++) {
    final parts = lines[i].trim().split(RegExp(r'\s+'));
    if (parts.length >= 6 && parts[5] == mount) {
      return (
        total: parseSize(parts[1]),
        used: parseSize(parts[2]),
        percent: double.tryParse(parts[4].replaceAll('%', '')) ?? 0,
      );
    }
  }
  return null;
}

/// Aggregate disk read/write sectors, skipping virtual devices.
({int read, int write})? parseDiskstats(String out) {
  var rd = 0, wr = 0, found = false;
  for (final line in out.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 14) continue;
    final name = parts[2];
    if (name.startsWith('loop') ||
        name.startsWith('ram') ||
        name.startsWith('dm-')) {
      continue;
    }
    final r = int.tryParse(parts[5]);
    final w = int.tryParse(parts[9]);
    if (r == null || w == null) continue;
    rd += r;
    wr += w;
    found = true;
  }
  return found ? (read: rd, write: wr) : null;
}

/// Aggregate network rx/tx bytes, skipping loopback.
({int rx, int tx})? parseNetdev(String out) {
  var rx = 0, tx = 0, found = false;
  final lines = out.split('\n');
  for (var i = 2; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final idx = line.indexOf(':');
    if (idx < 0) continue;
    final iface = line.substring(0, idx).trim();
    if (iface == 'lo') continue;
    final rest = line.substring(idx + 1).trim().split(RegExp(r'\s+'));
    if (rest.length < 9) continue;
    final r = int.tryParse(rest[0]);
    final t = int.tryParse(rest[8]);
    if (r == null || t == null) continue;
    rx += r;
    tx += t;
    found = true;
  }
  return found ? (rx: rx, tx: tx) : null;
}

double kbpsDelta(int cur, int prev, double secs) =>
    (cur - prev) / 1024 / (secs <= 0 ? 1 : secs);

double sectorsToKb(int delta, double secs) =>
    delta * 0.5 / (secs <= 0 ? 1 : secs);

const String collectScript = '''
echo "===STAT1==="
head -1 /proc/stat
echo "===DISK1==="
cat /proc/diskstats
echo "===NET1==="
cat /proc/net/dev
sleep 0.5
echo "===STAT2==="
head -1 /proc/stat
echo "===DISK2==="
cat /proc/diskstats
echo "===NET2==="
cat /proc/net/dev
echo "===MEM==="
free -m
echo "===DISKFS==="
df -h /
echo "===UPTIME==="
uptime
''';

String? _section(String all, String name) {
  final start = all.indexOf('===$name===\n');
  if (start < 0) return null;
  var from = start + '===$name===\n'.length;
  var end = all.indexOf('\n===', from);
  if (end < 0) end = all.length;
  var s = all.substring(from, end);
  while (s.isNotEmpty && (s.endsWith('\n') || s.endsWith('\r'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

({double a, double b, double c})? parseLoad(String out) {
  final idx = out.indexOf('load average:');
  if (idx < 0) return null;
  final parts = out
      .substring(idx + 'load average:'.length)
      .trim()
      .split(',')
      .map((e) => double.tryParse(e.trim()))
      .toList();
  if (parts.length < 3 || parts.any((e) => e == null)) return null;
  return (a: parts[0]!, b: parts[1]!, c: parts[2]!);
}

Future<HostMetrics> collectMetrics(SshService ssh) async {
  final out = await ssh.run(collectScript);
  final text = String.fromCharCodes(out);
  return parseMetricsText(text);
}

HostMetrics parseMetricsText(String out) {
  final cpu1 = _section(out, 'STAT1')?.trim().let(parseCpu);
  final cpu2 = _section(out, 'STAT2')?.trim().let(parseCpu);
  final disk1 = _section(out, 'DISK1')?.let(parseDiskstats);
  final disk2 = _section(out, 'DISK2')?.let(parseDiskstats);
  final net1 = _section(out, 'NET1')?.let(parseNetdev);
  final net2 = _section(out, 'NET2')?.let(parseNetdev);
  final mem = _section(out, 'MEM')?.let(parseMem);
  final diskFs = _section(out, 'DISKFS')?.let((s) => parseDf(s, '/'));
  final load = _section(out, 'UPTIME')?.let(parseLoad);

  final elapsed = 0.5;
  final m = HostMetrics();

  if (cpu1 != null && cpu2 != null) m.cpuPercent = cpuPercent(cpu1, cpu2);
  if (disk1 != null && disk2 != null) {
    m.ioReadKbps = sectorsToKb(disk2.read - disk1.read, elapsed);
    m.ioWriteKbps = sectorsToKb(disk2.write - disk1.write, elapsed);
  }
  if (net1 != null && net2 != null) {
    m.netRxKbps = kbpsDelta(net2.rx, net1.rx, elapsed);
    m.netTxKbps = kbpsDelta(net2.tx, net1.tx, elapsed);
  }
  if (mem != null) {
    m.memTotalMb = mem.total;
    m.memUsedMb = mem.used;
    m.memPercent = mem.total > 0 ? mem.used / mem.total * 100 : 0;
  }
  if (diskFs != null) {
    m.diskTotalGb = diskFs.total;
    m.diskUsedGb = diskFs.used;
    m.diskPercent = diskFs.percent;
  }
  if (load != null) {
    m.load1 = load.a;
    m.load5 = load.b;
    m.load15 = load.c;
  }
  return m;
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
