import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../providers/host_store.dart';

class HostFormDialog extends ConsumerStatefulWidget {
  final Host? editing;

  const HostFormDialog({super.key, this.editing});

  @override
  ConsumerState<HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends ConsumerState<HostFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _tagsCtrl;
  late AuthType _authType;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.editing;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _addrCtrl = TextEditingController(text: h?.address ?? '');
    _portCtrl = TextEditingController(text: (h?.port ?? 22).toString());
    _userCtrl = TextEditingController(text: h?.username ?? 'root');
    _passwordCtrl = TextEditingController();
    _groupCtrl = TextEditingController(text: h?.group ?? '默认');
    _tagsCtrl = TextEditingController(text: h?.tags.join(',') ?? '');
    _authType = h?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _groupCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final addr = _addrCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text) ?? 22;
    final user = _userCtrl.text.trim();
    if (name.isEmpty || addr.isEmpty || user.isEmpty) {
      setState(() => _error = '请填写名称、地址、用户名');
      return;
    }
    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final password = _passwordCtrl.text;

    final store = ref.read(hostStoreProvider.notifier);
    if (widget.editing == null) {
      final host = Host.create(
        name: name,
        address: addr,
        port: port,
        username: user,
        authType: _authType,
        authRef: _authType == AuthType.key ? null : null,
        group: _groupCtrl.text.trim().isEmpty ? '默认' : _groupCtrl.text.trim(),
        tags: tags,
      );
      await store.addHost(host,
          password: _authType == AuthType.password && password.isNotEmpty
              ? password
              : null);
    } else {
      final host = widget.editing!.copyWith(
        name: name,
        address: addr,
        port: port,
        username: user,
        authType: _authType,
        group: _groupCtrl.text.trim().isEmpty ? '默认' : _groupCtrl.text.trim(),
        tags: tags,
      );
      await store.updateHost(host,
          password: _authType == AuthType.password && password.isNotEmpty
              ? password
              : null);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑主机' : '添加主机'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '显示名称'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addrCtrl,
                      decoration: const InputDecoration(labelText: 'IP / 域名'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '端口'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: '用户名'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<AuthType>(
                      initialValue: _authType,
                      decoration: const InputDecoration(labelText: '认证方式'),
                      items: const [
                        DropdownMenuItem(
                          value: AuthType.password,
                          child: Text('密码'),
                        ),
                        DropdownMenuItem(
                          value: AuthType.key,
                          child: Text('私钥'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _authType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _authType == AuthType.key
                      ? '私钥内容（可选）'
                      : isEdit
                          ? '新密码（留空不修改）'
                          : '密码',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _groupCtrl,
                      decoration: const InputDecoration(labelText: '分组'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tagsCtrl,
                      decoration: const InputDecoration(labelText: '标签（逗号分隔）'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? '保存' : '添加'),
        ),
      ],
    );
  }
}
