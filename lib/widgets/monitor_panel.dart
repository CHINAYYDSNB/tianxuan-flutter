import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/metrics_service.dart';
import '../services/ssh_service.dart';

const int _historyLen = 60;

class MonitorPanel extends ConsumerStatefulWidget {
  final SshService ssh;

  const MonitorPanel({super.key, required this.ssh});

  @override
  ConsumerState<MonitorPanel> createState() => _MonitorPanelState();
}

class _MonitorPanelState extends ConsumerState<MonitorPanel> {
  HostMetrics? _metrics;
  Timer? _timer;

  final List<double> _ioRead = [];
  final List<double> _ioWrite = [];
  final List<double> _netRx = [];
  final List<double> _netTx = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _collect());
    _collect();
  }

  void _push(List<double> list, double v) {
    list.add(v);
    if (list.length > _historyLen) list.removeAt(0);
  }

  Future<void> _collect() async {
    try {
      final m = await collectMetrics(widget.ssh);
      if (!mounted) return;
      setState(() {
        _metrics = m;
        _push(_ioRead, m.ioReadKbps);
        _push(_ioWrite, m.ioWriteKbps);
        _push(_netRx, m.netRxKbps);
        _push(_netTx, m.netTxKbps);
      });
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
      return Center(
          child: Text('采集指标中...',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : Colors.black45)));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // high-contrast line colors; dark theme uses bright hues, light uses deep hues
    final ioReadColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final ioWriteColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final netRxColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
    final netTxColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _row('CPU', '${m.cpuPercent.toStringAsFixed(1)}%', m.cpuPercent,
            const Color(0xFF6366F1)),
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
        Text('IO 吞吐 (KB/s)',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 4),
        _lineChart(
          series: [
            (_series(_ioRead), ioReadColor),
            (_series(_ioWrite), ioWriteColor),
          ],
        ),
        const Divider(height: 24),
        Text('网络吞吐 (KB/s)',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 4),
        _lineChart(
          series: [
            (_series(_netRx), netRxColor),
            (_series(_netTx), netTxColor),
          ],
        ),
      ],
    );
  }

  List<FlSpot> _series(List<double> data) {
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i]),
      growable: false,
    );
  }

  Widget _lineChart({
    required List<(List<FlSpot>, Color)> series,
  }) {
    final maxVal = series.fold<double>(1, (acc, s) {
      final max = s.$1.fold<double>(0, (a, p) => p.y > a ? p.y : a);
      return max > acc ? max : acc;
    });
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: _historyLen.toDouble(),
          minY: 0,
          maxY: maxVal * 1.1,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: series
              .map((s) => LineChartBarData(
                    spots: s.$1,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: s.$2,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true,
                        color: s.$2.withValues(alpha: 0.08)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _row(String label, String text, double percent, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark ? Colors.white54 : Colors.black45;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: dimColor)),
            Text(text,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: textColor)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: isDark
                ? const Color(0xFF1E222A)
                : const Color(0xFFE0E3E8),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _labelRow(String label, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark ? Colors.white54 : Colors.black45;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: dimColor)),
          Text(text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}
