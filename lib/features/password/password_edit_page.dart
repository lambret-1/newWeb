import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/password_entry.dart';
import '../../core/services/password_service.dart';

/// 密码条目编辑页：添加或修改网站账号密码。
class PasswordEditPage extends StatefulWidget {
  final PasswordEntry? entry; // 为空则为新增
  final String? prefillDomain; // 从网页带入的域名
  final String? prefillUsername;
  final String? prefillPassword;

  const PasswordEditPage({
    super.key,
    this.entry,
    this.prefillDomain,
    this.prefillUsername,
    this.prefillPassword,
  });

  @override
  State<PasswordEditPage> createState() => _PasswordEditPageState();
}

class _PasswordEditPageState extends State<PasswordEditPage> {
  late final TextEditingController _domainCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _domainCtrl = TextEditingController(text: widget.entry?.domain ?? widget.prefillDomain ?? '');
    _usernameCtrl = TextEditingController(text: widget.entry?.username ?? widget.prefillUsername ?? '');
    _passwordCtrl = TextEditingController(text: widget.entry?.password ?? widget.prefillPassword ?? '');
    _titleCtrl = TextEditingController(text: widget.entry?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.entry?.note ?? '');
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final domain = _domainCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (domain.isEmpty) {
      setState(() => _error = '请输入网站域名');
      return;
    }
    if (username.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }

    final normalizedDomain = PasswordEntry.domainOf(domain.startsWith('http') ? domain : 'https://$domain');
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = PasswordEntry(
      id: widget.entry?.id,
      domain: normalizedDomain,
      username: username,
      password: password,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: now,
    );

    await PasswordService.instance.upsert(entry);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: Text(isEdit ? '编辑密码' : '添加密码',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF007AFF)),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16, color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection([
            _buildField(_domainCtrl, '网站域名', 'example.com', Icons.language),
            _buildDivider(),
            _buildField(_titleCtrl, '网站名称（可选）', '如：GitHub', Icons.title),
          ]),
          const SizedBox(height: 16),
          _buildSection([
            _buildField(_usernameCtrl, '用户名', '邮箱或账号', Icons.person_outline),
            _buildDivider(),
            _buildPasswordField(),
          ]),
          const SizedBox(height: 16),
          _buildSection([
            _buildField(_noteCtrl, '备注（可选）', '附加信息', Icons.notes, maxLines: 2),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          if (isEdit) ...[
            const SizedBox(height: 24),
            CupertinoButton(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('删除密码'),
                    content: Text('确定删除 ${widget.entry!.domain} 的密码吗？'),
                    actions: [
                      CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                    ],
                  ),
                );
                if (ok == true && widget.entry?.id != null) {
                  await PasswordService.instance.delete(widget.entry!.id!);
                  if (!mounted) return;
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('删除此密码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String placeholder,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF3A3A3C)))),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          const SizedBox(width: 80, child: Text('密码', style: TextStyle(fontSize: 15, color: Color(0xFF3A3A3C)))),
          Expanded(
            child: TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(height: 0.5, color: const Color(0xFFE5E5EA), margin: const EdgeInsets.only(left: 32));
}
