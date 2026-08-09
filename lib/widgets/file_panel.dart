import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/sftp_service.dart';

class FilePanel extends StatefulWidget {
  final SftpService sftp;

  const FilePanel({super.key, required this.sftp});

  @override
  State<FilePanel> createState() => _FilePanelState();
}

class _FilePanelState extends State<FilePanel> {
  String _path = '/root';
  List<SftpEntry> _entries = [];
  bool _loading = false;
  String? _error;
  final TextEditingController _pathCtrl = TextEditingController(text: '/root');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.sftp.list(_path);
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _pathCtrl.text = _path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _goTo(String dir) {
    setState(() => _path = dir);
    _refresh();
  }

  void _goUp() {
    if (_path == '/' || _path.isEmpty) return;
    final idx = _path.lastIndexOf('/');
    _goTo(idx <= 0 ? '/' : _path.substring(0, idx));
  }

  void _onDoubleTap(SftpEntry e) {
    if (e.isDir) {
      _goTo(e.path);
    } else {
      _openEditor(e);
    }
  }

  void _showMenu(TapDownDetails details, SftpEntry entry) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      items: [
        if (entry.isDir)
          const PopupMenuItem(value: 'cd', child: Text('跳转到此位置'))
        else
          const PopupMenuItem(value: 'open', child: Text('打开')),
        if (!entry.isDir) ...[
          const PopupMenuItem(value: 'download', child: Text('下载')),
        ],
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        const PopupMenuItem(value: 'info', child: Text('详细信息')),
        if (!entry.isDir) ...[
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'cd':
          _goTo(entry.path);
        case 'open':
          _openEditor(entry);
        case 'download':
          _download(entry);
        case 'rename':
          _rename(entry);
        case 'info':
          _showInfo(entry);
        case 'delete':
          _confirmDelete(entry);
      }
    });
  }

  Future<void> _openEditor(SftpEntry entry) async {
    String content;
    try {
      content = await widget.sftp.readText(entry.path);
    } catch (e) {
      _snack('读取失败: $e');
      return;
    }
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditFileDialog(path: entry.path, initial: content),
    );
    if (result != null) {
      try {
        await widget.sftp.writeText(entry.path, result);
        _snack('已保存');
      } catch (e) {
        _snack('保存失败: $e');
      }
    }
  }

  Future<void> _download(SftpEntry entry) async {
    final outDir = await FilePicker.platform.getDirectoryPath();
    if (outDir == null) return;
    try {
      await widget.sftp.download(entry.path, '$outDir\\${entry.name}');
      _snack('已下载到 $outDir');
    } catch (e) {
      _snack('下载失败: $e');
    }
  }

  Future<void> _rename(SftpEntry entry) async {
    final ctrl = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('确认')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    final newPath = '${entry.path.substring(0, entry.path.lastIndexOf('/') + 1)}$newName';
    try {
      await widget.sftp.rename(entry.path, newPath);
      _refresh();
    } catch (e) {
      _snack('重命名失败: $e');
    }
  }

  Future<void> _showInfo(SftpEntry entry) async {
    try {
      final st = await widget.sftp.stat(entry.path);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(entry.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('类型', entry.isDir ? '目录' : '文件'),
              _infoRow('大小', entry.isDir ? '-' : '${entry.size} bytes'),
              _infoRow('权限', '0${(st.mode?.value ?? 0).toRadixString(8)}'),
              _infoRow('修改时间', entry.modified?.toString() ?? '-'),
              _infoRow('属主', st.userID != null ? 'uid ${st.userID}' : '-'),
              _infoRow('属组', st.groupID != null ? 'gid ${st.groupID}' : '-'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭')),
          ],
        ),
      );
    } catch (e) {
      _snack('获取详情失败: $e');
    }
  }

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black45)),
            Text(v),
          ],
        ),
      );

  Future<void> _confirmDelete(SftpEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确认删除 ${entry.path}？'),
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
      try {
        await widget.sftp.remove(entry.path, isDir: entry.isDir);
        _refresh();
      } catch (e) {
        _snack('删除失败: $e');
      }
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    final name = file.name;
    try {
      await widget.sftp.upload(file.path!, '$_path/$name');
      _refresh();
      _snack('上传完成');
    } catch (e) {
      _snack('上传失败: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                tooltip: '上级',
                icon: const Icon(Icons.arrow_upward),
                onPressed: _goUp,
              ),
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (_) => _goTo(_pathCtrl.text),
                ),
              ),
              IconButton(
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
              IconButton(
                tooltip: '上传',
                icon: const Icon(Icons.upload_file),
                onPressed: _upload,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Expanded(
          child: _loading && _entries.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return InkWell(
                      onDoubleTap: () => _onDoubleTap(e),
                      onSecondaryTapDown: (d) => _showMenu(d, e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              e.isDir ? Icons.folder : Icons.insert_drive_file,
                              size: 16,
                              color: e.isDir
                                  ? Colors.amber.shade400
                                  : Colors.blueGrey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!e.isDir)
                              Text(_fmtSize(e.size),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white54
                                              : Colors.black45)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _EditFileDialog extends StatefulWidget {
  final String path;
  final String initial;

  const _EditFileDialog({required this.path, required this.initial});

  @override
  State<_EditFileDialog> createState() => _EditFileDialogState();
}

class _EditFileDialogState extends State<_EditFileDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.path,
          style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 520,
        height: 400,
        child: TextField(
          controller: _ctrl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(_ctrl.text),
            child: const Text('保存')),
      ],
    );
  }
}
