import 'dart:async';

import 'package:flutter/material.dart';

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
import 'reader_page.dart';
import 'settings_page.dart';
import 'tab_manager.dart';
import 'webview_page.dart';
import 'widgets/address_bar.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/progress_bar.dart';
import 'widgets/tab_switcher.dart';
import 'widgets/tool_bar.dart';

/// 浏览器主界面：地址栏 + 多标签 WebView + 手势层 + 工具栏。
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TabManager _tabManager = TabManager();
  final Map<String, GlobalKey<WebViewPageState>> _webViewKeys = {};

  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _incognito = false;
  StreamSubscription<Map<String, dynamic>>? _nativeSub;

  @override
  void initState() {
    super.initState();
    _tabManager.addTab();
    _tabManager.addListener(_onTabsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DatabaseHelper.instance.initDefaultBookmarks();
      AdBlockService.instance.init();
      DownloadService.instance.ensureListening();
    });
    _loadIncognito();
    _listenNativeEvents();
  }

  Future<void> _loadIncognito() async {
    final value = await SettingsService.instance.isIncognitoEnabled();
    if (!mounted) return;
    setState(() => _incognito = value);
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
    _tabManager.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onTabsChanged() {
    final active = _tabManager.activeTab;
    if (active != null) {
      _addressController.text = active.url;
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
    _currentWebView()?.load(input);
  }

  void _openTabSwitcher() {
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute(
            builder: (_) => TabSwitcherPage(
              manager: _tabManager,
              onNewTab: () {
                _tabManager.addTab();
                Navigator.of(context).pop();
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

  void _openMoreMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _sheetItem(
                icon: Icons.bookmark_border,
                label: '书签',
                onTap: () => _openBookmarks(sheetContext),
              ),
              _sheetItem(
                icon: Icons.history,
                label: '历史记录',
                onTap: () => _openHistory(sheetContext),
              ),
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
                icon: Icons.offline_pin_outlined,
                label: '离线页面',
                onTap: () => _openOfflinePages(sheetContext),
              ),
              _sheetItem(
                icon: Icons.file_download_outlined,
                label: '下载管理',
                onTap: () => _openDownloads(sheetContext),
              ),
              _sheetItem(
                icon: Icons.cleaning_services_outlined,
                label: '缓存管理',
                onTap: () => _openCacheManager(sheetContext),
              ),
              _sheetItem(
                icon: Icons.settings_outlined,
                label: '设置',
                onTap: () => _openSettings(sheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
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

  /// 截取当前激活标签的最后浏览快照。
  Future<void> _refreshSnapshot() async {
    final active = _tabManager.activeTab;
    if (active == null) return;
    final shot = await NativeBridge.captureVisibleWebView();
    if (!mounted) return;
    if (shot == null) return;
    final current = _tabManager.activeTab;
    if (current == null || current.id != active.id) return;
    current.snapshot = shot;
    _tabManager.notifySnapshotUpdated();
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
                AddressBar(
                  controller: _addressController,
                  onSubmit: _submit,
                  onReload: () => _currentWebView()?.reload(),
                ),
                ProgressBar(progress: _progress),
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
                return GestureLayer(
                  onEdgeBack: () => _currentWebView()?.goBack(),
                  onEdgeForward: () => _currentWebView()?.goForward(),
                  isAtTop: () async => _currentWebView()?.isAtTop() ?? true,
                  onRefresh: () async {
                    await _currentWebView()?.reload();
                  },
                  child: IndexedStack(
                    index: _tabManager.tabs.indexWhere((t) => t.id == activeId),
                    children: _tabManager.tabs.map((tab) {
                      final tabId = tab.id;
                      return WebViewPage(
                        key: _keyOf(tabId),
                        initialUrl: tab.url,
                        onProgress: _onProgress,
                        onUrlChanged: (url) {
                          if (url != null) {
                            _tabManager.updateTab(tabId, url: url);
                          }
                        },
                        onPageStarted: (url) {
                          _tabManager.updateTab(tabId, url: url, isLoading: true);
                        },
                        onPageFinished: (url) {
                          _onPageFinished(tabId, url);
                        },
                        onTitleChanged: (title) {
                          _tabManager.updateTab(tabId, title: title);
                        },
                        onOfflineCollected: _saveOfflineCollected,
                        onCanGoBackChanged: _onCanGoBackChanged,
                        onCanGoForwardChanged: _onCanGoForwardChanged,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          ToolBar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _currentWebView()?.goBack(),
            onForward: () => _currentWebView()?.goForward(),
            onHome: () => _currentWebView()?.goHome(),
            onTabs: _openTabSwitcher,
            onMore: _openMoreMenu,
          ),
        ],
      ),
    );
  }
}
