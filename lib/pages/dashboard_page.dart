import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../providers/host_store.dart';
import '../services/metrics_service.dart';
import '../services/ssh_service.dart';
import '../widgets/host_form_dialog.dart';
import 'host_workspace_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  final Map<String, HostMetrics> _metrics = {};
  final Map<String, Timer> _timers = {};
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    final was = _visible;
    _visible = visible;
    if (visible && !was) {
      // returning to foreground: force immediate refresh
      for (final hostId in _metrics.keys) {
        _collect(hostId, force: true);
      }
      _scheduleAll();
    }
  }

  void _start() async {
    await ref.read(hostStoreProvider.notifier).refresh();
    final hosts = ref.read(hostStoreProvider);
    for (final h in hosts) {
      _collect(h.id);
    }
    _scheduleAll();
  }

  void _scheduleAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    final interval = _visible
        ? const Duration(seconds: 1)
        : const Duration(seconds: 10);
    for (final hostId in _metrics.keys) {
      _timers[hostId] =
          Timer.periodic(interval, (_) => _collect(hostId));
    }
  }

  Future<void> _collect(String hostId, {bool force = false}) async {
    final hosts = ref.read(hostStoreProvider);
    final host = hosts.where((h) => h.id == hostId).firstOrNull;
    if (host == null) return;
    if (_metrics.containsKey(hostId) && !force) {
      // background refresh keeps cadence; skip if recently updated
    }
    try {
      final password =
          await ref.read(hostPasswordProvider(hostId).future);
      final ssh = SshService();
      await ssh.connect(host: host, password: password, logVerbose: false);
      final m = await collectMetrics(ssh);
      await ssh.disconnect();
      if (mounted) setState(() => _metrics[hostId] = m);
    } catch (_) {
      // offline: mark if never fetched
      if (mounted && !_metrics.containsKey(hostId)) {
        setState(() => _metrics[hostId] = HostMetrics.offline());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _openAddDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const HostFormDialog(),
    );
    _start();
  }

  Future<void> _openEditDialog(Host host) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => HostFormDialog(editing: host),
    );
    _start();
  }

  Future<void> _confirmDelete(Host host) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主机'),
        content: Text('确认删除 ${host.name}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(hostStoreProvider.notifier).deleteHost(host.id);
      _timers[host.id]?.cancel();
      _timers.remove(host.id);
      _metrics.remove(host.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(hostStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('总览 · ${hosts.length} 台主机'),
        actions: [
          IconButton(
            tooltip: '添加主机',
            icon: const Icon(Icons.add),
            onPressed: _openAddDialog,
          ),
        ],
      ),
      body: hosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('还没有主机',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('添加主机'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _start(),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemCount: hosts.length,
                itemBuilder: (context, i) => _HostCard(
                  host: hosts[i],
                  metrics: _metrics[hosts[i].id],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            HostWorkspacePage(host: hosts[i]),
                      ),
                    );
                  },
                  onEdit: () => _openEditDialog(hosts[i]),
                  onDelete: () => _confirmDelete(hosts[i]),
                ),
              ),
            ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final Host host;
  final HostMetrics? metrics;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HostCard({
    required this.host,
    required this.metrics,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final online = m?.online ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = isDark ? Colors.white54 : Colors.black45;
    final dimmer = isDark ? Colors.white38 : Colors.black38;
    final titleColor = isDark ? Colors.white : Colors.black87;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      host.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? const Color(0xFF10B981)
                          : const Color(0xFF52525B),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${host.username}@${host.address}:${host.port}',
                style: TextStyle(fontSize: 12, color: dim),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              if (m == null)
                Expanded(
                  child: Center(
                    child: Text('采集指标中...',
                        style: TextStyle(color: dimmer, fontSize: 12)),
                  ),
                )
              else if (!m.online)
                Expanded(
                  child: Center(
                    child: Text('无法连接 / 凭证缺失',
                        style: TextStyle(color: dimmer, fontSize: 12)),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bar('CPU', '${m.cpuPercent.toStringAsFixed(1)}%',
                          m.cpuPercent, const Color(0xFF6366F1), dim, isDark),
                      const SizedBox(height: 6),
                      _bar('内存',
                          '${m.memUsedMb}/${m.memTotalMb} MB',
                          m.memPercent, const Color(0xFF10B981), dim, isDark),
                      const SizedBox(height: 6),
                      _bar('磁盘',
                          '${m.diskUsedGb.toStringAsFixed(1)}/${m.diskTotalGb.toStringAsFixed(1)} G',
                          m.diskPercent, const Color(0xFFF59E0B), dim, isDark),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(String label, String text, double percent, Color color, Color dim, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: dim)),
            Text(text,
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: isDark
                ? const Color(0xFF1E222A)
                : const Color(0xFFE0E3E8),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
