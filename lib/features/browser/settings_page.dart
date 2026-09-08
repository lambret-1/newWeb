import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/adblock_custom_service.dart';
import '../../core/services/settings_service.dart';
import '../../native/native_bridge.dart';
import 'adblock_custom_page.dart';
import 'cache_manager_page.dart';
import '../password/password_vault_page.dart';
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
  String _version = '';
  bool _autoUpdateCheck = true;

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
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
    });
    final hasTencent = (await settings.getTencentSecretId()) != null;
    final mode = await settings.getTranslateMode();
    final domains = await settings.getAutoTranslateDomains();
    final autoUpdate = await settings.isAutoUpdateCheckEnabled();
    if (!mounted) return;
    setState(() {
      _searchEngine = engine;
      _adBlock = adBlock;
      _incognito = incognito;
      _hasTencent = hasTencent;
      _translateMode = mode;
      _autoTranslateDomains = domains;
      _autoUpdateCheck = autoUpdate;
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
    final action = await showModalBottomSheet<String>(
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
                '点击「立即安装」后在弹出菜单中选择「Safari」，'
                'Safari 会提示下载配置文件，随后到「设置→通用→VPN与设备管理」完成安装。',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.install_mobile,
                  size: 22, color: Color(0xFF007AFF)),
              title: const Text('立即安装', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop('install'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share,
                  size: 22, color: Color(0xFF3B82F6)),
              title: const Text('分享描述文件', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.close, size: 22, color: Color(0xFF374151)),
              title: const Text('取消', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop('cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'install') {
      final ok = await NativeBridge.openSystemURL(path);
      if (!ok && mounted) {
        _showMessage('无法打开，请尝试分享后用 Safari 打开');
      }
    } else if (action == 'share') {
      await Share.shareXFiles([XFile(path)]);
    }
  }

  /// 检查更新：调用 GitHub API 获取最新 Release，比较版本号。
  Future<void> _checkUpdate() async {
    _showMessage('正在检查更新...');
    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/lambret-1/newWeb/releases/latest'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        _showMessage('检查更新失败');
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final releaseUrl = data['html_url'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      // 查找 IPA 下载链接
      String? ipaUrl;
      final assets = (data['assets'] as List?) ?? [];
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final name = a['name'] as String? ?? '';
          if (name.endsWith('.ipa')) {
            ipaUrl = a['browser_download_url'] as String?;
            break;
          }
        }
      }

      if (latestTag.isEmpty) {
        _showMessage('检查更新失败');
        return;
      }

      final current = _version;
      final hasUpdate = _compareVersion(latestTag, current) > 0;

      if (!mounted) return;
      if (!hasUpdate) {
        _showMessage('已是最新版本 v$current');
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v$latestTag',
              style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本 v$current',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                if (body.isNotEmpty)
                  Text(body, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('稍后'),
            ),
            if (ipaUrl != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _downloadAndInstallIPA(ipaUrl!, latestTag);
                },
                child: const Text('立即更新'),
              )
            else
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (releaseUrl.isNotEmpty) {
                    await NativeBridge.openWebURL(releaseUrl);
                  }
                },
                child: const Text('前往下载'),
              ),
          ],
        ),
      );
    } catch (e) {
      _showMessage('检查更新失败：网络异常');
    }
  }

  /// 在 App 内下载 IPA 并唤起安装工具（不跳转 Safari）。
  Future<void> _downloadAndInstallIPA(String url, String version) async {
    _showMessage('正在下载 v$version，请稍候...');
    try {
      final req = http.Request('GET', Uri.parse(url));
      final streamed = await req.send().timeout(const Duration(minutes: 5));
      if (streamed.statusCode != 200) {
        _showMessage('下载失败（HTTP ${streamed.statusCode}），请稍后重试');
        return;
      }
      final bytes = await streamed.stream.toBytes();
      final tmp = await getTemporaryDirectory();
      final path = p.join(tmp.path, 'NewWeb-v$version.ipa');
      await File(path).writeAsBytes(bytes);
      _showMessage('下载完成（${(bytes.length / 1048576).toStringAsFixed(1)} MB），正在唤起安装工具...');
      await Future.delayed(const Duration(milliseconds: 800));
      final ok = await NativeBridge.openSystemURL(path);
      if (!ok) {
        _showMessage('无法打开文件，请到下载目录手动安装');
      }
    } catch (e) {
      _showMessage('下载失败：网络异常，请稍后重试');
    }
  }

  /// 比较版本号：返回 1 表示 a > b，-1 表示 a < b，0 表示相等。
  int _compareVersion(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final na = i < pa.length ? (pa[i] ?? 0) : 0;
      final nb = i < pb.length ? (pb[i] ?? 0) : 0;
      if (na > nb) return 1;
      if (na < nb) return -1;
    }
    return 0;
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
                subtitle: Text(
                  _adBlock
                      ? '已启用 ${5 + _customRuleCount()} 条规则（内置 5 + 自定义 ${_customRuleCount()}）'
                      : '资源拦截 + 元素隐藏 + 追踪拦截',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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
            title: '密码与隐私',
            children: [
              _tile(
                icon: Icons.password,
                title: '密码本',
                subtitle: '自动填充网站登录密码',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasswordVaultPage()),
                  );
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
                  _customRuleCount() > 0
                      ? '拦截${AdblockCustomService.instance.blockDomains.length} · 隐藏${AdblockCustomService.instance.hiddenSelectors.length} · 白名单${AdblockCustomService.instance.whitelist.length}'
                      : '未设置',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AdblockCustomPage()));
                  if (mounted) setState(() {});
                },
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
              ListTile(
                leading:
                    const Icon(Icons.info_outline, size: 22, color: Color(0xFF374151)),
                title: const Text('未来浏览器', style: TextStyle(fontSize: 15)),
                trailing: Text(
                  '版本 $_version',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
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
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome,
                    size: 22, color: Color(0xFF374151)),
                title: const Text('打开App自动检测更新', style: TextStyle(fontSize: 15)),
                subtitle: const Text('前台时自动检查新版本',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                value: _autoUpdateCheck,
                onChanged: (value) async {
                  setState(() => _autoUpdateCheck = value);
                  await SettingsService.instance.setAutoUpdateCheckEnabled(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.system_update,
                    size: 22, color: Color(0xFF374151)),
                title: const Text('检查更新',
                    style: TextStyle(fontSize: 15, color: Color(0xFF007AFF))),
                trailing: const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF9CA3AF)),
                onTap: _checkUpdate,
              ),
              ListTile(
                leading: const Icon(Icons.code,
                    size: 22, color: Color(0xFF374151)),
                title: const Text('项目仓库',
                    style: TextStyle(fontSize: 15, color: Color(0xFF007AFF))),
                subtitle: const Text('github.com/lambret-1/newWeb',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                trailing: const Icon(Icons.open_in_new,
                    size: 18, color: Color(0xFF9CA3AF)),
                onTap: () => NativeBridge.openWebURL(
                    'https://github.com/lambret-1/newWeb'),
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
