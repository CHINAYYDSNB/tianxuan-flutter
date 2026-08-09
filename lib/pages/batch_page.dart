import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../providers/host_store.dart';
import '../services/ssh_service.dart';

class BatchResult {
  final Host host;
  final String stdout;
  final String stderr;
  final int? exitCode;
  final bool success;
  final int elapsedMs;
  final String? error;

  BatchResult({
    required this.host,
    required this.stdout,
    required this.stderr,
    this.exitCode,
    required this.success,
    required this.elapsedMs,
    this.error,
  });
}

class BatchPage extends ConsumerStatefulWidget {
  const BatchPage({super.key});

  @override
  ConsumerState<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends ConsumerState<BatchPage> {
  final Set<String> _selected = {};
  final TextEditingController _cmdCtrl = TextEditingController();
  final List<BatchResult> _results = [];
  final List<String> _history = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(hostStoreProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _cmdCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final hosts = ref.read(hostStoreProvider);
    final targets = hosts.where((h) => _selected.contains(h.id)).toList();
    final cmd = _cmdCtrl.text.trim();
    if (targets.isEmpty || cmd.isEmpty) return;

    setState(() {
      _running = true;
      _results.clear();
    });

    final results = <BatchResult>[];
    await Future.wait(targets.map((host) async {
      final sw = Stopwatch()..start();
      try {
        final password =
            await ref.read(hostPasswordProvider(host.id).future);
        final ssh = SshService();
        await ssh.connect(host: host, password: password);
        final out = await ssh.run(cmd);
        await ssh.disconnect();
        sw.stop();
        final text = String.fromCharCodes(out);
        results.add(BatchResult(
          host: host,
          stdout: text,
          stderr: '',
          exitCode: 0,
          success: true,
          elapsedMs: sw.elapsedMilliseconds,
        ));
      } catch (e) {
        sw.stop();
        results.add(BatchResult(
          host: host,
          stdout: '',
          stderr: '',
          success: false,
          elapsedMs: sw.elapsedMilliseconds,
          error: '$e',
        ));
      }
    }));

    if (mounted) {
      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _running = false;
        if (!_history.contains(cmd)) {
          _history.insert(0, cmd);
          if (_history.length > 20) _history.removeLast();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(hostStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('批量命令')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // host selection
          Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0F13),
              border: Border(right: BorderSide(color: Color(0xFF1E222A))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('主机',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${_selected.length} 已选',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: hosts.map((h) {
                      return CheckboxListTile(
                        dense: true,
                        title: Text(h.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${h.address}:${h.port}',
                            style: const TextStyle(fontSize: 11)),
                        value: _selected.contains(h.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(h.id);
                          } else {
                            _selected.remove(h.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // command + results
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cmdCtrl,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: '输入要批量执行的命令，如: uptime',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _run(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _running ? null : _run,
                        child: _running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('执行'),
                      ),
                    ],
                  ),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _history
                            .map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(c,
                                        style:
                                            const TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      _cmdCtrl.text = c;
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: _results.isEmpty
                        ? const Center(
                            child: Text('选择主机并输入命令后点击「执行」',
                                style: TextStyle(color: Colors.white38)))
                        : ListView(
                            children: _results
                                .map((r) => _ResultTile(result: r))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatefulWidget {
  final BatchResult result;

  const _ResultTile({required this.result});

  @override
  State<_ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends State<_ResultTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Card(
      color: const Color(0xFF16191F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    r.success ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: r.success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.host.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text('exit ${r.exitCode ?? '-'} · ${r.elapsedMs}ms',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F13),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4)),
              ),
              child: r.error != null
                  ? Text(r.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12))
                  : SelectableText(
                      r.stdout,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
            ),
        ],
      ),
    );
  }
}
