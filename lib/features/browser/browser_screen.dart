import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import 'bookmarks_page.dart';
import 'history_page.dart';
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

  @override
  void initState() {
    super.initState();
    _tabManager.addTab();
    _tabManager.addListener(_onTabsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DatabaseHelper.instance.initDefaultBookmarks();
    });
  }

  @override
  void dispose() {
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
          }
        });
  }

  void _openMoreMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
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
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showComingSoon('设置');
              },
            ),
            const SizedBox(height: 8),
          ],
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

  void _showComingSoon(String feature) {
    _showMessage('$feature 将在 M3 里程碑提供');
  }

  /// 页面加载完成：更新标签元数据并写入历史。
  void _onPageFinished(String tabId, String url) {
    final tab = _tabManager.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return;
    _tabManager.updateTab(tabId, isLoading: false, url: url);
    DatabaseHelper.instance.addHistory(tab.title, url);
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
