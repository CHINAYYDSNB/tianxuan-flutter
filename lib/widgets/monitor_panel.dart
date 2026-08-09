import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/metrics_service.dart';
import '../services/ssh_service.dart';

class MonitorPanel extends ConsumerStatefulWidget {
  final SshService ssh;

  const MonitorPanel({super.key, required this.ssh});

  @override
  ConsumerState<MonitorPanel> createState() => _MonitorPanelState();
}

class _MonitorPanelState extends ConsumerState<MonitorPanel> {
  HostMetrics? _metrics;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _collect());
    _collect();
  }

  Future<void> _collect() async {
    try {
      final m = await collectMetrics(widget.ssh);
      if (mounted) setState(() => _metrics = m);
    } catch (_) {
      // keep previous
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    if (m == null) {
      return const Center(
          child: Text('采集指标中...', style: TextStyle(color: Colors.white54)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _row('CPU', '${m.cpuPercent.toStringAsFixed(1)}%',
            m.cpuPercent, const Color(0xFF6366F1)),
        const SizedBox(height: 10),
        _row('内存',
            '${m.memUsedMb}/${m.memTotalMb} MB (${m.memPercent.toStringAsFixed(0)}%)',
            m.memPercent, const Color(0xFF10B981)),
        const SizedBox(height: 10),
        _row('磁盘',
            '${m.diskUsedGb.toStringAsFixed(1)}/${m.diskTotalGb.toStringAsFixed(1)} G (${m.diskPercent.toStringAsFixed(0)}%)',
            m.diskPercent, const Color(0xFFF59E0B)),
        const SizedBox(height: 10),
        _labelRow('负载',
            '${m.load1.toStringAsFixed(2)} / ${m.load5.toStringAsFixed(2)} / ${m.load15.toStringAsFixed(2)}'),
        const Divider(height: 24),
        const Text('IO 吞吐',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        _labelRow('读', '${m.ioReadKbps.toStringAsFixed(1)} KB/s'),
        _labelRow('写', '${m.ioWriteKbps.toStringAsFixed(1)} KB/s'),
        const Divider(height: 24),
        const Text('网络吞吐',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        _labelRow('下行', '${m.netRxKbps.toStringAsFixed(1)} KB/s'),
        _labelRow('上行', '${m.netTxKbps.toStringAsFixed(1)} KB/s'),
      ],
    );
  }

  Widget _row(String label, String text, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Text(text,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: const Color(0xFF1E222A),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _labelRow(String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}
