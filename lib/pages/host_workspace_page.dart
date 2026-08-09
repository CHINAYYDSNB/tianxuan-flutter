import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../providers/host_store.dart';
import '../services/sftp_service.dart';
import '../services/ssh_service.dart';
import '../widgets/file_panel.dart';
import '../widgets/monitor_panel.dart';
import '../widgets/terminal_widget.dart';

class HostWorkspacePage extends ConsumerStatefulWidget {
  final Host host;

  const HostWorkspacePage({super.key, required this.host});

  @override
  ConsumerState<HostWorkspacePage> createState() => _HostWorkspacePageState();
}

class _HostWorkspacePageState extends ConsumerState<HostWorkspacePage>
    with SingleTickerProviderStateMixin {
  final SshService _ssh = SshService();
  final SftpService _sftp = SftpService();
  bool _connecting = false;
  String? _error;
  bool _sftpReady = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final password =
          await ref.read(hostPasswordProvider(widget.host.id).future);
      await _ssh.connect(host: widget.host, password: password);
      await _ssh.startShell();
      await _sftp.init(_ssh);
      if (mounted) setState(() => _sftpReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ssh.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.host.name} (${widget.host.address}:${widget.host.port})'),
        actions: [
          if (_connecting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: '重新连接',
            icon: const Icon(Icons.refresh),
            onPressed: _connect,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _connect, child: Text('重试')),
                      ],
                    ),
                  )
                : TerminalWidget(ssh: _ssh),
          ),
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xFF0D0F13),
              border: Border(left: BorderSide(color: Color(0xFF1E222A))),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '监控'),
                    Tab(text: '文件'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      MonitorPanel(ssh: _ssh),
                      _sftpReady
                          ? FilePanel(sftp: _sftp)
                          : const Center(
                              child: Text('SFTP 初始化中...',
                                  style: TextStyle(color: Colors.white54))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
