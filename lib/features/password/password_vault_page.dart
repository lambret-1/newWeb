import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/password_entry.dart';
import '../../core/services/password_service.dart';
import 'master_password_page.dart';
import 'password_edit_page.dart';

/// 密码本管理页：查看、添加、编辑、删除网站密码。
class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  List<PasswordEntry> _entries = [];
  bool _loading = true;
  bool _autoFillEnabled = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await PasswordService.instance.getAll();
    final autoFill = await PasswordService.instance.isAutoFillEnabled();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _autoFillEnabled = autoFill;
      _loading = false;
    });
  }

  List<PasswordEntry> get _filtered {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) =>
        e.domain.toLowerCase().contains(q) ||
        e.username.toLowerCase().contains(q) ||
        (e.title?.toLowerCase().contains(q) ?? false)).toList();
  }

  Future<void> _verifyAndOpen(Widget page) async {
    final hasMaster = await PasswordService.instance.hasMasterPassword();
    if (hasMaster) {
      final ok = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(builder: (_) => const MasterPasswordPage()),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: const Text('密码本', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF007AFF)),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => _verifyAndOpen(const PasswordEditPage()),
            child: const Icon(Icons.add, size: 24, color: Color(0xFF007AFF)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // 搜索框
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '搜索网站或账号',
                              hintStyle: TextStyle(fontSize: 15, color: Colors.grey),
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 自动填充开关
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_fix_high, size: 20, color: Color(0xFF007AFF)),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('自动填充登录表单', style: TextStyle(fontSize: 15))),
                        CupertinoSwitch(
                          value: _autoFillEnabled,
                          activeColor: const Color(0xFF007AFF),
                          onChanged: (v) async {
                            await PasswordService.instance.setAutoFillEnabled(v);
                            setState(() => _autoFillEnabled = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 密码列表
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) => _buildCard(_filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.password_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_searchQuery.isNotEmpty ? '没有找到匹配的密码' : '还没有保存的密码',
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text(_searchQuery.isNotEmpty ? '换个关键词试试' : '点击右上角 + 添加第一个密码',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildCard(PasswordEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _verifyAndOpen(PasswordEditPage(entry: entry)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 域名首字母图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.domain.isNotEmpty ? entry.domain[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title ?? entry.domain,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.username} · ${entry.domain}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
