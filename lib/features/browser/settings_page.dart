import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/adblock_custom_service.dart';
import '../../core/services/settings_service.dart';
import '../../native/native_bridge.dart';
import 'adblock_custom_page.dart';
import 'cache_manager_page.dart';
import 'debug_log_page.dart';

/// 设置页：搜索引擎 / 广告拦截（含豁免站点）/ 无痕 / 网页翻译 / 缓存 / DNS / 关于。
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
  String _translateMode = 'auto';
  List<String> _autoTranslateDomains = [];

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
    final hasTencent = (await settings.getTencentSecretId()) != null;
    final mode = await settings.getTranslateMode();
    final domains = await settings.getAutoTranslateDomains();
    if (!mounted) return;
    setState(() {
      _searchEngine = engine;
      _adBlock = adBlock;
      _incognito = incognito;
      _hasTencent = hasTencent;
      _translateMode = mode;
      _autoTranslateDomains = domains;
    });
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

  int _customRuleCount() {
    final svc = AdblockCustomService.instance;
    return svc.blockDomains.length +
        svc.hiddenSelectors.length +
        svc.whitelist.length +
        svc.advancedRules.length;
  }

  Future<void> _pickTranslateMode() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.translateModes.entries.map((entry) {
            return ListTile(
              leading: Icon(
                entry.key == _translateMode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: entry.key == _translateMode
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
    if (selected == null || selected == _translateMode) return;
    await SettingsService.instance.setTranslateMode(selected);
    setState(() => _translateMode = selected);
  }

  /// 域名列表编辑对话框。
  Future<void> _editDomains({
    required String title,
    required String hint,
    required List<String> current,
    required Future<void> Function(List<String>) save,
  }) async {
    final controller = TextEditingController();
    final items = List<String>.from(current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        final v = controller.text.trim().toLowerCase();
                        if (v.isNotEmpty && !items.contains(v)) {
                          setDialogState(() => items.add(v));
                          controller.clear();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '暂无条目',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (_, index) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              items[index],
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFB0B7C3)),
                              onPressed: () => setDialogState(
                                  () => items.removeAt(index)),
                            ),
                          ),
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
      ),
    );
    if (saved == true) {
      await save(items);
      _load();
    }
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

  Future<void> _generateDNS() async {
    final path = await NativeBridge.generateDNSProfile();
    if (!mounted) return;
    if (path == null) {
      _showMessage('生成失败');
      return;
    }
    final share = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '已生成 AdGuard DNS 配置描述文件',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '分享该文件后用「Safari」打开即可安装。安装后系统 DNS 将使用 '
                'AdGuard DNS，在域名解析层拦截广告与追踪。',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.ios_share,
                  size: 22, color: Color(0xFF3B82F6)),
              title: const Text('分享描述文件', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.close, size: 22, color: Color(0xFF374151)),
              title: const Text('取消', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (share == true) {
      await Share.shareXFiles([XFile(path)]);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final engineName = SettingsService.searchEngines[_searchEngine] ?? '百度';
    final modeName = SettingsService.translateModes[_translateMode] ?? '自动';
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
            title: '通用',
            children: [
              _tile(
                icon: Icons.search,
                title: '搜索引擎',
                trailing: Text(
                  engineName,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: _pickSearchEngine,
              ),
              SwitchListTile(
                secondary:
                    const Icon(Icons.block, size: 22, color: Color(0xFF374151)),
                title: const Text('广告拦截', style: TextStyle(fontSize: 15)),
                subtitle: const Text(
                  '资源拦截 + 元素隐藏 + 追踪拦截',
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
            title: '广告拦截',
            children: [
              _tile(
                icon: Icons.rule,
                title: '自定义规则',
                trailing: Text(
                  '${_customRuleCount()}',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AdblockCustomPage())),
              ),
              const ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                title: Text(
                  '拦截域名 / 隐藏元素 / 豁免站点 / 高级 JSON 规则',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
          _group(
            title: '网页翻译',
            children: [
              _tile(
                icon: Icons.translate,
                title: '翻译模式',
                trailing: Text(
                  modeName,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: _pickTranslateMode,
              ),
              _tile(
                icon: Icons.auto_awesome,
                title: '自动翻译网址',
                trailing: Text(
                  '${_autoTranslateDomains.length} 个',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                onTap: () => _editDomains(
                  title: '自动翻译网址',
                  hint: '如 en.wikipedia.org',
                  current: _autoTranslateDomains,
                  save: SettingsService.instance.setAutoTranslateDomains,
                ),
              ),
              _tile(
                icon: Icons.cloud_outlined,
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
            title: '隐私',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined,
                    size: 22, color: Color(0xFF374151)),
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
            title: '存储',
            children: [
              _tile(
                icon: Icons.cleaning_services_outlined,
                title: '缓存管理（四级）',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CacheManagerPage())),
              ),
            ],
          ),
          _group(
            title: 'DNS 过滤',
            children: [
              _tile(
                icon: Icons.dns_outlined,
                title: '安装 AdGuard DNS',
                subtitle: '域名解析层拦截广告与追踪',
                onTap: _generateDNS,
              ),
            ],
          ),
          _group(
            title: '关于',
            children: [
              const ListTile(
                leading:
                    Icon(Icons.info_outline, size: 22, color: Color(0xFF374151)),
                title: Text('未来浏览器', style: TextStyle(fontSize: 15)),
                trailing: Text(
                  '版本 1.0.9',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined,
                    size: 22, color: Color(0xFF374151)),
                title: const Text('调试日志', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF9CA3AF)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DebugLogPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _group({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF374151)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      trailing: trailing ??
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC4C9D3)),
      onTap: onTap,
    );
  }
}
