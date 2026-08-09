import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../models/panel.dart';
import '../providers/panel_store.dart';

class PanelListPage extends ConsumerStatefulWidget {
  const PanelListPage({super.key});

  @override
  ConsumerState<PanelListPage> createState() => _PanelListPageState();
}

class _PanelListPageState extends ConsumerState<PanelListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(panelStoreProvider.notifier).refresh();
    });
  }

  Future<void> _openForm({Panel? editing}) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => PanelFormDialog(editing: editing),
    );
  }

  Future<void> _confirmDelete(Panel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除面板'),
        content: Text('确认删除 ${p.name}？'),
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
      await ref.read(panelStoreProvider.notifier).deletePanel(p.id);
    }
  }

  void _openPanel(Panel p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PanelViewerPage(panel: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panels = ref.watch(panelStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('面板'),
        actions: [
          IconButton(
            tooltip: '添加面板',
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: panels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('还没有面板',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('添加面板'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: panels.map((p) {
                return Card(
                  child: InkWell(
                    onDoubleTap: () => _openPanel(p),
                    onSecondaryTapDown: (d) {
                      showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(d.globalPosition.dx,
                            d.globalPosition.dy, 0, 0),
                        items: const [
                          PopupMenuItem(value: 'open', child: Text('打开')),
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ).then((v) {
                        switch (v) {
                          case 'open':
                            _openPanel(p);
                          case 'edit':
                            _openForm(editing: p);
                          case 'delete':
                            _confirmDelete(p);
                        }
                      });
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0x336366F1),
                        child: const Icon(Icons.language, size: 18),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x336366F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              p.type == PanelType.bt ? '宝塔' : '1Panel',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(p.url,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class PanelFormDialog extends ConsumerStatefulWidget {
  final Panel? editing;

  const PanelFormDialog({super.key, this.editing});

  @override
  ConsumerState<PanelFormDialog> createState() => _PanelFormDialogState();
}

class _PanelFormDialogState extends ConsumerState<PanelFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late PanelType _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editing?.name ?? '');
    _urlCtrl = TextEditingController(text: widget.editing?.url ?? '');
    _type = widget.editing?.type ?? PanelType.bt;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;

    final store = ref.read(panelStoreProvider.notifier);
    if (widget.editing == null) {
      await store.addPanel(Panel.create(name: name, url: url, type: _type));
    } else {
      // FIX: editing calls updatePanel, not addPanel (was the bug)
      final updated = widget.editing!.copyWith(name: name, url: url, type: _type);
      await store.updatePanel(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑面板' : '添加面板'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '面板名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                  labelText: '面板地址',
                  hintText: 'https://panel.example.com:8888'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PanelType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '面板类型'),
              items: const [
                DropdownMenuItem(value: PanelType.bt, child: Text('宝塔 (BT)')),
                DropdownMenuItem(value: PanelType.onePanel, child: Text('1Panel')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        FilledButton(onPressed: _save, child: Text(isEdit ? '保存' : '添加')),
      ],
    );
  }
}

class PanelViewerPage extends StatefulWidget {
  final Panel panel;

  const PanelViewerPage({super.key, required this.panel});

  @override
  State<PanelViewerPage> createState() => _PanelViewerPageState();
}

class _PanelViewerPageState extends State<PanelViewerPage> {
  final _controller = WebviewController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.setDefaultContextMenusEnabled(true);
      await _controller.loadUrl(widget.panel.url);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '打开失败: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.panel.name)),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text('请确认已安装 WebView2 Runtime',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _controller.value.isInitialized
              ? Webview(_controller)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
