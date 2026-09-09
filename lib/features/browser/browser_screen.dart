import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/models/password_entry.dart';
import '../../core/services/debug_logger.dart';
import '../../core/services/password_service.dart';
import '../../core/services/site_security_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/database_helper.dart';
import '../../core/services/adblock_service.dart';
import '../../core/services/download_service.dart';
import '../../core/services/offline_service.dart';
import '../../core/services/settings_service.dart';
import '../../native/native_bridge.dart';
import 'bookmarks_page.dart';
import 'cache_manager_page.dart';
import 'download_page.dart';
import 'history_page.dart';
import 'offline_pages_page.dart';
import '../password/password_vault_page.dart';
import 'reader_page.dart';
import 'screenshot_result_page.dart';
import 'settings_page.dart';
import 'source_code_page.dart';
import 'tab_manager.dart';
import 'webview_page.dart';
import 'widgets/address_bar.dart';
import 'widgets/address_suggestions.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/progress_bar.dart';
import 'widgets/site_security_sheet.dart';
import 'widgets/tab_switcher.dart';
import 'widgets/tool_bar.dart';
import 'widgets/top_tab_bar.dart';

/// 浏览器主界面：地址栏 + 多标签 WebView + 手势层 + 工具栏。
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> with WidgetsBindingObserver {
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final TabManager _tabManager = TabManager();
  final Map<String, GlobalKey<WebViewPageState>> _webViewKeys = {};

  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _incognito = false;
  bool _isLoading = false;
  SecurityLevel _securityLevel = SecurityLevel.secure;
  SiteSecurityConfig? _siteConfig;
  StreamSubscription<Map<String, dynamic>>? _nativeSub;

  // 地址栏增强
  List<SuggestionItem> _suggestions = [];
  bool _showSuggestions = false;
  String? _clipboardUrl;
  String _tempSearchEngine = 'baidu';
  bool _addressBarVisible = true;
  bool _autoHideEnabled = false;
  bool _clipboardDetectEnabled = true;
  bool _isAddressFocused = false;
  DateTime? _lastClipboardCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabManager.addListener(_onTabsChanged);
    unawaited(_initTabs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DatabaseHelper.instance.initDefaultBookmarks();
      AdBlockService.instance.init();
      DownloadService.instance.ensureListening();
      DownloadService.instance.completedTask.addListener(_onDownloadCompleted);
      // 启动 3 秒后自动检查更新
      Future.delayed(const Duration(seconds: 3), _autoCheckUpdate);
    });
    _loadIncognito();
    _listenNativeEvents();
    _addressController.addListener(_onAddressChanged);
    _loadAddressBarSettings();
  }

  void _onAddressChanged() {
    _updateSuggestions(_addressController.text);
  }

  Future<void> _loadAddressBarSettings() async {
    final clipboard = await SettingsService.instance.isClipboardDetectEnabled();
    final autoHide = await SettingsService.instance.isAutoHideAddressBarEnabled();
    final engine = await SettingsService.instance.getSearchEngine();
    if (!mounted) return;
    setState(() {
      _clipboardDetectEnabled = clipboard;
      _autoHideEnabled = autoHide;
      _tempSearchEngine = engine;
    });
  }

  /// 前台/后台生命周期变化：回到前台时自动检查更新 + 剪贴板检测。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoCheckUpdate();
      _checkClipboardUrl();
    }
  }

  /// 下载完成全局弹窗提示。
  void _onDownloadCompleted() {
    final task = DownloadService.instance.completedTask.value;
    if (task == null || !mounted) return;
    DownloadService.instance.completedTask.value = null;
    final name = task.fileName ?? '下载文件';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('下载完成', style: TextStyle(fontSize: 16)),
        content: Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final files = await DownloadService.instance.listCompletedFiles();
              final match = files.where((f) => f.name == name).toList();
              if (match.isNotEmpty) {
                await Share.shareXFiles([XFile(match.first.path)]);
              }
            },
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final files = await DownloadService.instance.listCompletedFiles();
              final match = files.where((f) => f.name == name).toList();
              if (match.isNotEmpty) {
                await NativeBridge.previewFile(match.first.path);
              }
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  /// 初始化标签：优先恢复上次会话（非无痕），否则新建默认标签。
  Future<void> _initTabs() async {
    final incognito = await SettingsService.instance.isIncognitoEnabled();
    if (mounted && incognito) setState(() => _incognito = true);
    await _tabManager.setPersistSession(!incognito);
    if (!incognito) {
      final restored = await _tabManager.restoreSession();
      if (restored) return;
    }
    _tabManager.addTab();
  }

  Future<void> _loadIncognito() async {
    final value = await SettingsService.instance.isIncognitoEnabled();
    if (!mounted) return;
    setState(() => _incognito = value);
    await _tabManager.setPersistSession(!value);
  }

  /// 监听原生事件：长按菜单动作（翻译此页 / 下载链接/图片）。
  void _listenNativeEvents() {
    _nativeSub = NativeBridge.events().listen((e) {
      final event = e['event'] as String?;
      if (event == null) return;
      switch (event) {
        case 'translatePage':
          _translatePage();
        case 'download':
          final url = e['url'] as String? ?? '';
          if (url.isNotEmpty) {
            _confirmDownload(url);
          }
      }
    }, onError: (Object e) {
      debugPrint('[Browser] 原生事件错误: $e');
    });
  }

  /// 下载前确认弹窗。
  Future<void> _confirmDownload(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开始下载？'),
        content: Text(
          url,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('下载'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      DownloadService.instance.start(url);
      _showMessage('已开始下载');
    }
  }

  @override
  void dispose() {
    _nativeSub?.cancel();
    _tabManager.removeListener(_onTabsChanged);
    DownloadService.instance.completedTask.removeListener(_onDownloadCompleted);
    WidgetsBinding.instance.removeObserver(this);
    _tabManager.dispose();
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _onTabsChanged() {
    final active = _tabManager.activeTab;
    if (active != null) {
      _addressController.text = active.url;
      _updateSecurityState(active.url);
    }
  }

  GlobalKey<WebViewPageState> _keyOf(String tabId) =>
      _webViewKeys.putIfAbsent(tabId, () => GlobalKey<WebViewPageState>());

  WebViewPageState? _currentWebView() =>
      _webViewKeys[_tabManager.activeTabId]?.currentState;

  void _onProgress(double progress) => setState(() => _progress = progress);

  void _onCanGoBackChanged(bool value) => setState(() => _canGoBack = value);

  void _onCanGoForwardChanged(bool value) => setState(() => _canGoForward = value);

  void _submit(String input) {
    FocusScope.of(context).unfocus();
    setState(() => _showSuggestions = false);
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;
    // 判断是否为网址
    final isUrl = _isLikelyUrl(trimmed);
    if (isUrl) {
      final url = trimmed.toLowerCase().startsWith('http') ? trimmed : 'https://$trimmed';
      _currentWebView()?.load(url);
    } else {
      // 搜索关键词
      final searchUrl = SettingsService.searchUrlOf(_tempSearchEngine);
      _currentWebView()?.load('$searchUrl${Uri.encodeComponent(trimmed)}');
    }
  }

  /// 判断输入是否为网址（比简单 contains('.') 更严格）。
  bool _isLikelyUrl(String text) {
    final lower = text.toLowerCase();
    // 明确的协议开头
    if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
    // localhost / IP 地址
    if (lower.startsWith('localhost') || RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(lower)) return true;
    // 包含点且无空格，且点后有 2-6 个字母（常见域名后缀）
    if (text.contains('.') && !text.contains(' ')) {
      final parts = text.split('.');
      if (parts.length >= 2) {
        final last = parts.last;
        // 常见顶级域名或 2-6 位字母
        if (RegExp(r'^[a-z]{2,6}$').hasMatch(last) || last.contains(':')) {
          return true;
        }
      }
    }
    return false;
  }

  // MARK: - 地址栏联想

  Future<void> _updateSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final history = await DatabaseHelper.instance.getHistory(limit: 200);
    final bookmarks = await DatabaseHelper.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _suggestions = filterSuggestions(query, history, bookmarks);
      _showSuggestions = true;
    });
  }

  void _onSelectSuggestion(String url) {
    _addressController.text = url;
    _submit(url);
  }

  Future<void> _deleteHistorySuggestion(String url) async {
    await DatabaseHelper.instance.deleteHistoryByUrl(url);
    _updateSuggestions(_addressController.text);
  }

  // MARK: - 剪贴板网址检测

  Future<void> _checkClipboardUrl() async {
    if (!_clipboardDetectEnabled) return;
    // 冷却时间：30秒内不重复检测，避免频繁触发系统剪贴板提示
    final now = DateTime.now();
    if (_lastClipboardCheck != null &&
        now.difference(_lastClipboardCheck!).inSeconds < 30) {
      return;
    }
    _lastClipboardCheck = now;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;
      final isUrl = _isLikelyUrl(text);
      if (isUrl && text != _tabManager.activeTab?.url) {
        if (!mounted) return;
        setState(() => _clipboardUrl = text);
      }
    } catch (_) {}
  }

  // MARK: - 复制链接

  void _copyCurrentLink() {
    final url = _tabManager.activeTab?.url ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    _showMessage('链接已复制');
  }

  // MARK: - 搜索引擎切换

  void _switchSearchEngine(String engine) {
    setState(() => _tempSearchEngine = engine);
    _showMessage('已切换为${SettingsService.searchEngines[engine] ?? engine}搜索');
  }

  // MARK: - 地址栏自动隐藏

  DateTime? _lastScrollHideTime;

  void _onWebViewScroll(double direction) {
    if (!_autoHideEnabled) return;
    if (_isAddressFocused) return; // 地址栏聚焦时不隐藏
    // 节流：200ms 内只处理一次，避免频繁 setState
    final now = DateTime.now();
    if (_lastScrollHideTime != null &&
        now.difference(_lastScrollHideTime!).inMilliseconds < 200) {
      return;
    }
    _lastScrollHideTime = now;
    // direction > 0 向下滚动（隐藏），< 0 向上滚动（显示）
    if (direction > 8 && _addressBarVisible) {
      setState(() => _addressBarVisible = false);
    } else if (direction < -8 && !_addressBarVisible) {
      setState(() => _addressBarVisible = true);
    }
  }

  /// 地址栏聚焦状态变化。
  void _onAddressFocusChanged(bool focused) {
    setState(() => _isAddressFocused = focused);
    if (!focused) {
      setState(() => _showSuggestions = false);
    }
  }

  /// 页面顶部轻下拉时聚焦地址栏。
  void _pullToFocusAddressBar() {
    if (!_addressBarVisible) {
      setState(() => _addressBarVisible = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addressFocusNode.requestFocus();
    });
  }

  /// 点击页面区域时让地址栏失焦。
  void _unfocusAddress() {
    if (_addressFocusNode.hasFocus) {
      _addressFocusNode.unfocus();
    }
  }

  void _openTabSwitcher() {
    FocusScope.of(context).unfocus();
    // 先截当前页快照（最多等 800ms），再打开标签切换页，确保快照最新
    _refreshSnapshot(delay: 0).timeout(
      const Duration(milliseconds: 800),
      onTimeout: () {},
    ).then((_) {
      if (!mounted) return;
      _pushTabSwitcher();
    });
  }

  void _pushTabSwitcher() {
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute(
            builder: (_) => TabSwitcherPage(
              manager: _tabManager,
              onNewTab: () {
                _tabManager.addTab(url: 'about:blank');
                Navigator.of(context).pop();
              },
              onCloseSelected: (ids) {
                if (ids.isEmpty) {
                  // 关闭全部
                  for (final t in _tabManager.tabs.toList()) {
                    _tabManager.closeTab(t.id);
                  }
                } else {
                  for (final id in ids) {
                    _tabManager.closeTab(id);
                  }
                }
              },
              onBookmarkSelected: (ids) async {
                var count = 0;
                for (final id in ids) {
                  final tab = _tabManager.tabs
                      .where((t) => t.id == id)
                      .firstOrNull;
                  if (tab == null ||
                      tab.url.isEmpty ||
                      tab.url.startsWith('about:')) {
                    continue;
                  }
                  final existing =
                      await DatabaseHelper.instance.findBookmarkByUrl(tab.url);
                  if (existing == null) {
                    await DatabaseHelper.instance
                        .addBookmark(tab.title, tab.url);
                    count++;
                  }
                }
                if (mounted) {
                  _showMessage(count > 0
                      ? '已添加 $count 个书签'
                      : '没有可添加的书签');
                }
              },
            ),
          ),
        )
        .then((selectedTabId) {
          if (selectedTabId != null && mounted) {
            _tabManager.switchTab(selectedTabId);
            _refreshSnapshot();
          }
        });
  }

  /// 从 GitHub 获取最新 Release 信息。返回 (版本号, 更新内容, Release链接, IPA下载链接)。
  Future<(String, String, String, String?)> _fetchLatestRelease() async {
    final resp = await http.get(
      Uri.parse('https://api.github.com/repos/lambret-1/newWeb/releases/latest'),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final latestTag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
    final releaseUrl = data['html_url'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    // 查找 IPA 下载链接（不用 firstOrNull，改用循环确保可靠）
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
    return (latestTag, body, releaseUrl, ipaUrl);
  }

  /// 自动检查更新：前台时触发，检查间隔 5 分钟，跳过用户已忽略的版本。
  Future<void> _autoCheckUpdate() async {
    if (!mounted) return;
    final settings = SettingsService.instance;
    final enabled = await settings.isAutoUpdateCheckEnabled();
    DebugLogger.instance.log('自动检查: 开关=$enabled', module: LogModule.update);
    if (!enabled) return;

    final lastCheck = await settings.getLastUpdateCheck();
    final now = DateTime.now().millisecondsSinceEpoch;
    final interval = now - lastCheck;
    DebugLogger.instance.log('自动检查: 距上次 ${(interval / 60000).toStringAsFixed(1)} 分钟', module: LogModule.update);
    // 检查间隔 5 分钟
    if (lastCheck > 0 && interval < 5 * 60 * 1000) {
      DebugLogger.instance.log('自动检查: 间隔不足 5 分钟，跳过', module: LogModule.update);
      return;
    }

    await settings.setLastUpdateCheck(now);

    try {
      DebugLogger.instance.log('自动检查: 开始请求 GitHub API', module: LogModule.update);
      final (latestTag, body, releaseUrl, ipaUrl) = await _fetchLatestRelease();
      DebugLogger.instance.log('自动检查: 最新版本=$latestTag, IPA=${ipaUrl != null ? "有" : "无"}', module: LogModule.update);
      if (latestTag.isEmpty) {
        DebugLogger.instance.log('自动检查: 版本号为空，终止', module: LogModule.update);
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      DebugLogger.instance.log('自动检查: 当前版本=$current, 比较结果=${_compareVersion(latestTag, current)}', module: LogModule.update);
      if (_compareVersion(latestTag, current) <= 0) {
        DebugLogger.instance.log('自动检查: 已是最新版本，不提示', module: LogModule.update);
        return;
      }

      // 检查是否是用户跳过的版本
      final skipped = await settings.getUpdateSkippedVersion();
      DebugLogger.instance.log('自动检查: 跳过版本=$skipped', module: LogModule.update);
      if (skipped == latestTag) {
        DebugLogger.instance.log('自动检查: 用户已跳过该版本，不提示', module: LogModule.update);
        return;
      }

      if (!mounted) return;
      DebugLogger.instance.log('自动检查: 弹出更新提示', module: LogModule.update);
      _showUpdateDialog(latestTag, current, body, releaseUrl, ipaUrl);
    } catch (e) {
      DebugLogger.instance.log('自动检查: 异常 $e', module: LogModule.update);
      // 静默失败，不打扰用户
    }
  }

  /// 比较版本号：1 表示 a > b，-1 表示 a < b，0 表示相等。
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

  /// 更新提示弹窗。
  void _showUpdateDialog(
    String latestVersion,
    String currentVersion,
    String body,
    String releaseUrl,
    String? ipaUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最新版本 v$latestVersion（当前 v$currentVersion）',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF))),
              const SizedBox(height: 8),
              if (body.isNotEmpty)
                Text(body, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SettingsService.instance.setUpdateSkippedVersion(latestVersion);
            },
            child: const Text('稍后提醒我'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (ipaUrl != null) {
                await _downloadAndInstallIPA(ipaUrl, latestVersion);
              } else if (releaseUrl.isNotEmpty) {
                await NativeBridge.openWebURL(releaseUrl);
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 在 App 内下载 IPA 并唤起全能签等签名工具安装（不跳转 Safari）。
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

  void _openMoreMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              // 顶部拖拽横条
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
              // 第一段：常用功能网格（4列）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _gridItem(
                      icon: Icons.bookmark_border,
                      label: '书签',
                      onTap: () => _openBookmarks(sheetContext),
                    ),
                    _gridItem(
                      icon: Icons.history,
                      label: '历史',
                      onTap: () => _openHistory(sheetContext),
                    ),
                    _gridItem(
                      icon: Icons.file_download_outlined,
                      label: '下载',
                      onTap: () => _openDownloads(sheetContext),
                    ),
                    _gridItem(
                      icon: Icons.settings_outlined,
                      label: '设置',
                      onTap: () => _openSettings(sheetContext),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              // 第二段：网页操作
              _sectionTitle('网页操作'),
              _sheetItem(
                icon: Icons.add,
                label: '添加到书签',
                onTap: () => _addBookmark(sheetContext),
              ),
              _sheetItem(
                icon: Icons.translate,
                label: '翻译此页',
                onTap: () => _translatePageFromSheet(sheetContext),
              ),
              _sheetItem(
                icon: Icons.menu_book_outlined,
                label: '阅读模式',
                onTap: () => _openReader(sheetContext),
              ),
              _sheetItem(
                icon: Icons.download_outlined,
                label: '保存离线页面',
                onTap: () => _saveOffline(sheetContext),
              ),
              _sheetItem(
                icon: Icons.password_outlined,
                label: '密码本',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasswordVaultPage()),
                  );
                },
              ),
              _sheetItem(
                icon: Icons.straighten,
                label: '网页长截图',
                onTap: () => _captureFullPage(sheetContext),
              ),
              _sheetItem(
                icon: Icons.image_outlined,
                label: '导出网页 PDF',
                onTap: () => _exportPDF(sheetContext),
              ),
              _sheetItem(
                icon: Icons.code,
                label: '查看网页源码',
                onTap: () => _viewSourceCode(sheetContext),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              // 第三段：其他
              _sectionTitle('其他'),
              _sheetItem(
                icon: Icons.cleaning_services_outlined,
                label: '缓存管理',
                onTap: () => _openCacheManager(sheetContext),
              ),
              _sheetItem(
                icon: Icons.offline_pin_outlined,
                label: '离线页面',
                onTap: () => _openOfflinePages(sheetContext),
              ),
              const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - 网页长截图

  Future<void> _captureFullPage(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;
    // 显示持续加载对话框，长截图可能需要数秒
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('正在滚动截取整页，请稍候...')),
          ],
        ),
      ),
    );
    String? base64;
    String? errMsg;
    try {
      base64 = await NativeBridge.captureFullPage(activeTab.url)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        errMsg = '截图超时，页面可能过长';
        return null;
      });
    } catch (e) {
      errMsg = '长截图生成失败';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭加载框
    if (base64 == null || base64.isEmpty) {
      _showMessage(errMsg ?? '长截图生成失败');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScreenshotResultPage(
        base64Image: base64!,
        pageUrl: activeTab.url,
        pageTitle: activeTab.title,
      ),
    ));
  }

  // MARK: - 导出网页 PDF

  Future<void> _exportPDF(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('正在生成 PDF...')),
          ],
        ),
      ),
    );
    final result = await NativeBridge.exportPDF(activeTab.url, activeTab.title);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (result?['success'] != true) {
      _showMessage('PDF 导出失败');
    }
  }

  // MARK: - 查看网页源码

  void _viewSourceCode(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SourceCodePage(url: activeTab.url, title: activeTab.title),
    ));
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _gridItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }

  Widget _sheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF374151)),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC7C7CC)),
      onTap: onTap,
    );
  }

  void _openBookmarks(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const BookmarksPage()))
        .then((url) {
      if (url != null && mounted) {
        _currentWebView()?.load(url);
      }
    });
  }

  void _openHistory(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const HistoryPage()))
        .then((url) {
      if (url != null && mounted) {
        _currentWebView()?.load(url);
      }
    });
  }

  Future<void> _addBookmark(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    final active = _tabManager.activeTab;
    if (active == null || active.url.isEmpty || active.url.startsWith('about:')) {
      _showMessage('当前页面无法添加书签');
      return;
    }
    final existing = await DatabaseHelper.instance.findBookmarkByUrl(active.url);
    if (existing != null) {
      _showMessage('该书签已存在');
      return;
    }
    await DatabaseHelper.instance.addBookmark(active.title, active.url);
    if (!mounted) return;
    _showMessage('已添加到书签');
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

  /// 保存离线页面：触发当前页采集，结果经 JS Bridge 回传后落盘。
  void _saveOffline(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    final webView = _currentWebView();
    if (webView == null) return;
    _showMessage('正在保存离线页面…');
    webView.saveOffline();
  }

  void _saveOfflineCollected(String title, String url, String html) async {
    try {
      await OfflineService.instance.save(title, url, html);
      if (!mounted) return;
      _showMessage('离线页面已保存');
    } catch (e) {
      debugPrint('[Offline] 保存失败: $e');
      if (!mounted) return;
      _showMessage('离线保存失败');
    }
  }

  void _openOfflinePages(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const OfflinePagesPage()))
        .then((path) {
      if (path != null && mounted) {
        _currentWebView()?.loadFile(path);
      }
    });
  }

  void _openSettings(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsPage()))
        .then((_) => _loadIncognito());
  }

  /// 翻译此页（已翻译则恢复原文）。
  void _translatePageFromSheet(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    _translatePage();
  }

  Future<void> _translatePage() async {
    final webView = _currentWebView();
    if (webView == null) return;
    final result = await webView.translatePage();
    if (!mounted) return;
    switch (result) {
      case 'started':
        _showMessage('正在翻译当前页面…');
      case 'restored':
        _showMessage('已恢复原文');
      case 'noop':
        _showMessage('当前页面没有可翻译的文本');
    }
  }

  /// 阅读模式：提取正文并打开阅读页。
  void _openReader(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    final webView = _currentWebView();
    if (webView == null) return;
    _showMessage('正在提取正文…');
    webView.extractReader().then((data) {
      if (!mounted) return;
      if (data == null || data['html'] == null || data['html']!.isEmpty) {
        _showMessage('未提取到正文内容');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderPage(
            title: data['title'] ?? '阅读模式',
            html: data['html']!,
            sourceUrl: data['url'] ?? '',
          ),
        ),
      );
    });
  }

  void _openDownloads(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const DownloadPage()));
  }

  void _openCacheManager(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const CacheManagerPage()));
  }

  /// 页面加载完成：更新标签元数据并写入历史（无痕模式下不记录）。
  void _onPageFinished(String tabId, String url) {
    final tab = _tabManager.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return;
    _tabManager.updateTab(tabId, isLoading: false, url: url);
    if (!_incognito) {
      DatabaseHelper.instance.addHistory(tab.title, url);
    }
    _refreshSnapshot();
  }

  /// 根据 URL 更新地址栏安全锁头状态。
  Future<void> _updateSecurityState(String url) async {
    final level = url.startsWith('https://')
        ? SecurityLevel.secure
        : SecurityLevel.insecure;
    final domain = SiteSecurityManager.domainOf(url);
    final config = await SiteSecurityManager.instance.getConfig(domain);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _securityLevel = level;
      _siteConfig = config;
    });
  }

  /// 点击锁头弹出底部安全详情面板。
  void _openSecuritySheet() {
    final activeTab = _tabManager.activeTab;
    if (activeTab == null) return;
    final domain = SiteSecurityManager.domainOf(activeTab.url);
    final config = _siteConfig ?? SiteSecurityConfig(domain: domain);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SiteSecuritySheet(
          domain: domain,
          level: _securityLevel,
          isTabLocked: activeTab.isLocked,
          adBlockCount: 0,
          dnsEnabled: true,
          config: config,
          onToggleLock: (locked) {
            _tabManager.setLocked(activeTab.id, locked);
          },
          onForceHttps: (enabled) async {
            final newConfig = SiteSecurityConfig(domain: domain)
              ..forceHttps = enabled
              ..camera = config.camera
              ..microphone = config.microphone
              ..location = config.location
              ..photo = config.photo
              ..popup = config.popup;
            await SiteSecurityManager.instance.saveConfig(newConfig);
            setState(() => _siteConfig = newConfig);
          },
          onCameraChanged: (p) => _updatePermission(domain, config, (c) => c.camera = p),
          onMicrophoneChanged: (p) => _updatePermission(domain, config, (c) => c.microphone = p),
          onLocationChanged: (p) => _updatePermission(domain, config, (c) => c.location = p),
          onPhotoChanged: (p) => _updatePermission(domain, config, (c) => c.photo = p),
          onPopupChanged: (p) => _updatePermission(domain, config, (c) => c.popup = p),
          onClearSiteData: () {
            SiteSecurityManager.instance.clearDomain(domain);
            _showMessage('已清除 $domain 的配置');
          },
        ),
      ),
    );
  }

  /// 更新站点权限并保存。
  Future<void> _updatePermission(
    String domain,
    SiteSecurityConfig old,
    void Function(SiteSecurityConfig) mutate,
  ) async {
    final newConfig = SiteSecurityConfig(domain: domain)
      ..forceHttps = old.forceHttps
      ..camera = old.camera
      ..microphone = old.microphone
      ..location = old.location
      ..photo = old.photo
      ..popup = old.popup;
    mutate(newConfig);
    await SiteSecurityManager.instance.saveConfig(newConfig);
    setState(() => _siteConfig = newConfig);
  }

  /// 检测到登录表单：查找匹配密码并自动填充。
  Future<void> _onLoginFormDetected(String tabId, String url) async {
    final autoFill = await PasswordService.instance.isAutoFillEnabled();
    if (!autoFill) return;
    final domain = _domainOf(url);
    final entries = await PasswordService.instance.findByDomain(domain);
    if (entries.isEmpty) return;
    // 取最近更新的一条自动填充
    final entry = entries.first;
    final webView = _webViewKeys[tabId]?.currentState;
    await webView?.fillLoginForm(entry.username, entry.password);
    DebugLogger.instance.log('🔑 自动填充登录表单: $domain (${entry.username})');
  }

  /// 登录表单提交：弹出保存密码提示。
  Future<void> _onLoginFormSubmitted(
    String url,
    String username,
    String password,
  ) async {
    if (username.isEmpty || password.isEmpty) return;
    final domain = _domainOf(url);
    // 检查是否已存在相同账号
    final existing = await PasswordService.instance.findOne(domain, username);
    if (existing != null && existing.password == password) return; // 已保存且密码相同

    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.password, size: 40, color: Color(0xFF007AFF)),
              const SizedBox(height: 12),
              Text(
                existing != null ? '更新 $domain 的密码？' : '保存 $domain 的密码？',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '账号：$username\n密码将安全保存在本设备',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text(existing != null ? '更新密码' : '保存密码',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                onPressed: () => Navigator.pop(ctx, 'never'),
                child: Text('不再询问此网站',
                    style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'save') {
      final now = DateTime.now().millisecondsSinceEpoch;
      await PasswordService.instance.upsert(
        PasswordEntry(
          id: existing?.id,
          domain: domain,
          username: username,
          password: password,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (mounted) _showMessage('密码已保存');
    }
  }

  String _domainOf(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host;
    } catch (_) {
      return url;
    }
  }

  /// 截取当前激活标签的最后浏览快照（无痕模式不截图），写入磁盘持久化。
  /// [delay] 等待页面渲染稳定的毫秒数（页面加载完成后用 400ms，即时截图用 0）。
  Future<void> _refreshSnapshot({int delay = 400}) async {
    if (_incognito) {
      DebugLogger.instance.log(' 无痕模式，跳过截图');
      return;
    }
    final active = _tabManager.activeTab;
    if (active == null) {
      DebugLogger.instance.log(' activeTab 为 null，跳过');
      return;
    }
    DebugLogger.instance.log(' _refreshSnapshot 入口, tabId=${active.id}, url=${active.url}, delay=$delay');
    if (delay > 0) await Future.delayed(Duration(milliseconds: delay));
    final current = _tabManager.activeTab;
    if (current == null || current.id != active.id) {
      DebugLogger.instance.log(' 延迟后 tab 已切换，跳过');
      return;
    }
    final shot = await NativeBridge.captureSnapshot(active.url);
    if (!mounted) return;
    if (shot == null) {
      DebugLogger.instance.log(' ❌ NativeBridge.captureSnapshot 返回 null');
      return;
    }
    DebugLogger.instance.log(' ✅ 原生截图成功, bytes=${shot.length}');
    // 写入稳定磁盘路径（App 重启后仍可读）
    try {
      final dir = await getApplicationSupportDirectory();
      final snapDir = Directory('${dir.path}/snapshots');
      if (!snapDir.existsSync()) snapDir.createSync(recursive: true);
      final file = File('${snapDir.path}/${active.id}.png');
      await file.writeAsBytes(shot);
      DebugLogger.instance.log(' ✅ 写入 AppSupport 成功, path=${file.path}, exists=${file.existsSync()}');
      _tabManager.updateSnapshot(active.id, bytes: shot, diskPath: file.path);
    } catch (e) {
      DebugLogger.instance.log(' ❌ 写入 AppSupport 失败, error=$e，仅存内存');
      _tabManager.updateSnapshot(active.id, bytes: shot);
    }
  }

  /// 分享当前网页（调用 iOS 系统分享面板）。
  void _shareCurrentPage() {
    final tab = _tabManager.activeTab;
    if (tab == null) return;
    final url = tab.url;
    final title = tab.title;
    if (url.isEmpty || url == 'about:blank') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前页面无法分享'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Share.share(url, subject: title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 剪贴板网址提示条
                if (_clipboardUrl != null)
                  Container(
                    color: const Color(0xFFE3F2FD),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.content_paste, size: 14, color: Color(0xFF007AFF)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '发现剪贴板网址：$_clipboardUrl',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1E)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final url = _clipboardUrl!;
                            setState(() => _clipboardUrl = null);
                            _addressController.text = url;
                            _submit(url);
                          },
                          child: const Text('打开', style: TextStyle(fontSize: 13, color: Color(0xFF007AFF))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF8E8E93)),
                          onPressed: () => setState(() => _clipboardUrl = null),
                        ),
                      ],
                    ),
                  ),
                ListenableBuilder(
                  listenable: _tabManager,
                  builder: (context, _) {
                    final activeTab = _tabManager.activeTab;
                    return AddressBar(
                      controller: _addressController,
                      onSubmit: _submit,
                      onReload: () => _currentWebView()?.reload(),
                      securityLevel: _securityLevel,
                      isLoading: _isLoading,
                      isTabLocked: activeTab?.isLocked ?? false,
                      onTapLock: _openSecuritySheet,
                      currentUrl: activeTab?.url ?? '',
                      onGoBack: () => _currentWebView()?.goBack(),
                      onGoForward: () => _currentWebView()?.goForward(),
                      canGoBack: _canGoBack,
                      canGoForward: _canGoForward,
                      searchEngine: _tempSearchEngine,
                      onSwitchSearchEngine: _switchSearchEngine,
                      onCopyLink: _copyCurrentLink,
                      onFocusChanged: _onAddressFocusChanged,
                      focusNode: _addressFocusNode,
                      visible: _addressBarVisible,
                    );
                  },
                ),
                ProgressBar(progress: _progress),
                ListenableBuilder(
                  listenable: _tabManager,
                  builder: (context, _) => TopTabBar(
                    tabManager: _tabManager,
                    onSwitch: (id) {
                      _tabManager.switchTab(id);
                      _refreshSnapshot();
                    },
                    onClose: (id) {
                      final tab = _tabManager.tabs
                          .where((t) => t.id == id)
                          .firstOrNull;
                      if (tab?.isLocked ?? false) return;
                      _tabManager.closeTab(id);
                      if (_tabManager.tabs.isEmpty) {
                        _tabManager.addTab(url: 'https://www.baidu.com');
                      }
                    },
                    onEditTitle: (id, title) {
                      if (title.isEmpty) {
                        _tabManager.setCustomTitle(id, null);
                      } else {
                        _tabManager.setCustomTitle(id, title);
                      }
                    },
                    onEditUrl: (id, url) {
                      _tabManager.switchTab(id);
                      _tabManager.updateTab(id, url: url);
                      _addressController.text = url;
                      _currentWebView()?.load(url);
                    },
                    onToggleLock: (id, locked) {
                      _tabManager.setLocked(id, locked);
                    },
                    onAdd: () {
                      _tabManager.addTab(url: 'https://www.baidu.com');
                    },
                  ),
                ),
                if (_incognito)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: const Text(
                      '无痕浏览中 · 不记录历史记录',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _tabManager,
              builder: (context, _) {
                final activeId = _tabManager.activeTabId;
                return Stack(
                  children: [
                    GestureLayer(
                      onEdgeBack: () => _currentWebView()?.goBack(),
                      onEdgeForward: () => _currentWebView()?.goForward(),
                      isAtTop: () async => _currentWebView()?.isAtTop() ?? true,
                      onRefresh: () async {
                        await _currentWebView()?.reload();
                      },
                      onPullToFocus: _pullToFocusAddressBar,
                      onTapPage: _unfocusAddress,
                      child: IndexedStack(
                    index: _tabManager.tabs.indexWhere((t) => t.id == activeId),
                    children: _tabManager.tabs.map((tab) {
                      final tabId = tab.id;
                      final keepAlive = _tabManager.keepAliveTabIds;
                      return WebViewPage(
                        key: _keyOf(tabId),
                        initialUrl: tab.url,
                        active: keepAlive.contains(tabId),
                        snapshotBytes: tab.snapshot,
                        snapshotPath: tab.snapshotPath,
                        initialScrollY: tab.scrollY,
                        onScrollSaved: (dy) {
                          _tabManager.updateTab(tabId, scrollY: dy);
                        },
                        onProgress: _onProgress,
                        onUrlChanged: (url) {
                          if (url != null) {
                            _tabManager.updateTab(tabId, url: url);
                          }
                        },
                        onPageStarted: (url) {
                          _tabManager.updateTab(tabId, url: url, isLoading: true);
                          if (tabId == _tabManager.activeTabId) {
                            setState(() {
                              _isLoading = true;
                              _addressBarVisible = true;
                            });
                          }
                        },
                        onPageFinished: (url) {
                          _onPageFinished(tabId, url);
                          if (tabId == _tabManager.activeTabId) {
                            _updateSecurityState(url);
                          }
                        },
                        onTitleChanged: (title) {
                          _tabManager.updateTab(tabId, title: title);
                        },
                        onOfflineCollected: _saveOfflineCollected,
                        onCanGoBackChanged: _onCanGoBackChanged,
                        onCanGoForwardChanged: _onCanGoForwardChanged,
                        onLoginFormDetected: (url) => _onLoginFormDetected(tabId, url),
                        onLoginFormSubmitted: (url, username, password) =>
                            _onLoginFormSubmitted(url, username, password),
                        onScrollDirection: (dir) {
                          if (tabId == _tabManager.activeTabId) {
                            _onWebViewScroll(dir);
                          }
                        },
                      );
                    }).toList(),
                  ),
                    ),
                    // 联想下拉浮层
                    if (_showSuggestions)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AddressSuggestions(
                          suggestions: _suggestions,
                          onSelect: _onSelectSuggestion,
                          onDeleteHistory: _deleteHistorySuggestion,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ToolBar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _currentWebView()?.goBack(),
            onForward: () => _currentWebView()?.goForward(),
            onShare: _shareCurrentPage,
            onTabs: _openTabSwitcher,
            onMore: _openMoreMenu,
            tabCount: _tabManager.count,
          ),
        ],
      ),
    );
  }
}
