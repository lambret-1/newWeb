import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../../native/native_bridge.dart';

/// 设置页：搜索引擎 / 广告拦截 / 无痕模式 / 翻译配置 / 缓存管理 / 关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _searchEngine = 'baidu';
  bool _adBlock = false;
  bool _incognito = false;
  bool _hasTencent = false;
  int _cacheSize = -1; // -1 表示未加载

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = SettingsService.instance;
    final engine = await settings.getSearchEngine();
    final adBlock = await settings.isAdBlockEnabled();
    final incognito = await settings.isIncognitoEnabled();
    final hasTencent =
        (await settings.getTencentSecretId()) != null;
    final cacheSize = await NativeBridge.getCacheSize();
    if (!mounted) return;
    setState(() {
      _searchEngine = engine;
      _adBlock = adBlock;
      _incognito = incognito;
      _hasTencent = hasTencent;
      _cacheSize = cacheSize;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 0) return '读取中…';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _pickSearchEngine() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.searchEngines.entries.map((entry) {
            return ListTile(
              leading: Icon(
                entry.key == _searchEngine
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: entry.key == _searchEngine
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF9CA3AF),
              ),
              title: Text(entry.value, style: const TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop(entry.key),
            );
          }).toList(),
        ),
      ),
    );
    if (selected == null || selected == _searchEngine) return;
    await SettingsService.instance.setSearchEngine(selected);
    setState(() => _searchEngine = selected);
  }

  Future<void> _configureTencent() async {
    final idController = TextEditingController();
    final keyController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('腾讯云翻译配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '可选配置。未配置时自动使用免费翻译服务（Google / MyMemory / 本地词库）。',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'SecretId',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'SecretKey',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final id = idController.text.trim();
    final key = keyController.text.trim();
    if (id.isEmpty || key.isEmpty) return;
    await SettingsService.instance.setTencentKeys(id, key);
    setState(() => _hasTencent = true);
  }

  Future<void> _clearTencent() async {
    await SettingsService.instance.clearTencentKeys();
    setState(() => _hasTencent = false);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('将清除全部网站缓存、Cookie 与本地存储数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cacheSize = -1);
    await NativeBridge.clearWebData();
    final size = await NativeBridge.getCacheSize();
    if (!mounted) return;
    setState(() => _cacheSize = size);
  }

  @override
  Widget build(BuildContext context) {
    final engineName =
        SettingsService.searchEngines[_searchEngine] ?? '百度';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          _group(
            children: [
              _tile(
                icon: Icons.search,
                title: '搜索引擎',
                trailing: Text(
                  engineName,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: _pickSearchEngine,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.block, size: 22, color: Color(0xFF374151)),
                title: const Text('广告拦截', style: TextStyle(fontSize: 15)),
                subtitle: const Text(
                  '隐藏常见广告元素',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                value: _adBlock,
                onChanged: (value) async {
                  setState(() => _adBlock = value);
                  await SettingsService.instance.setAdBlockEnabled(value);
                },
              ),
            ],
          ),
          _group(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined, size: 22, color: Color(0xFF374151)),
                title: const Text('无痕模式', style: TextStyle(fontSize: 15)),
                subtitle: const Text(
                  '不记录历史；退出无痕时清空全部网站数据',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                value: _incognito,
                onChanged: (value) async {
                  if (!value) {
                    await NativeBridge.clearWebData();
                  }
                  setState(() => _incognito = value);
                  await SettingsService.instance.setIncognitoEnabled(value);
                },
              ),
            ],
          ),
          _group(
            children: [
              _tile(
                icon: Icons.translate,
                title: '腾讯云翻译',
                trailing: Text(
                  _hasTencent ? '已配置' : '未配置',
                  style: TextStyle(
                    fontSize: 14,
                    color: _hasTencent
                        ? const Color(0xFF52C41A)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                onTap: _configureTencent,
              ),
              if (_hasTencent)
                _tile(
                  icon: Icons.delete_outline,
                  title: '清除翻译密钥',
                  onTap: _clearTencent,
                ),
            ],
          ),
          _group(
            children: [
              _tile(
                icon: Icons.cleaning_services_outlined,
                title: '缓存管理',
                trailing: Text(
                  _formatSize(_cacheSize),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: _clearCache,
              ),
            ],
          ),
          _group(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, size: 22, color: Color(0xFF374151)),
                title: Text('未来浏览器', style: TextStyle(fontSize: 15)),
                trailing: Text(
                  '版本 1.0.2',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _group({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF374151)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC4C9D3)),
      onTap: onTap,
    );
  }
}
