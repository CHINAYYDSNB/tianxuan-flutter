import 'dart:io';

import 'package:flutter/material.dart';

import '../pages/replay_page.dart';
import '../services/recording_service.dart';

class RecorderPanel extends StatefulWidget {
  final RecordingService recorder;
  final String hostName;
  final VoidCallback onConnect;

  const RecorderPanel({
    super.key,
    required this.recorder,
    required this.hostName,
    required this.onConnect,
  });

  @override
  State<RecorderPanel> createState() => _RecorderPanelState();
}

class _RecorderPanelState extends State<RecorderPanel> {
  List<File> _files = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final files = await RecordingService.list();
      if (mounted) setState(() => _files = files);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (widget.recorder.isRecording) {
      final session = widget.recorder.stop();
      await RecordingService.save(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('录像已保存（${(session.durationMs / 1000).toStringAsFixed(1)}s）')),
        );
      }
      await _loadList();
    } else {
      if (!widget.recorder.isRecording) {
        widget.recorder.start(widget.hostName);
      }
      widget.onConnect();
      if (mounted) setState(() {});
    }
  }

  Future<void> _replay(File f) async {
    final session = await RecordingService.load(f);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReplayPage(session: session)),
    );
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除录像'),
        content: Text('确认删除 ${f.uri.pathSegments.last}？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await RecordingService.delete(f);
      await _loadList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recorder.isRecording;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: recording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6366F1),
                  ),
                  onPressed: _toggle,
                  icon: Icon(recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(recording ? '停止录制' : '开始录制'),
                ),
              ),
            ],
          ),
        ),
        if (recording)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text('录制中...',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black45)),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _files.isEmpty
                  ? Center(
                      child: Text('暂无录像',
                          style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white38
                                  : Colors.black38)),
                    ): ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, i) {
                        final f = _files[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.movie, size: 18),
                          title: Text(
                            f.uri.pathSegments.last,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _replay(f),
                          trailing: IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => _delete(f),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
