
import 'package:flutter/foundation.dart';

/// 浏览器标签元数据（WebViewController 由各 WebViewPage 内部持有）。
class BrowserTab {
  BrowserTab({required this.id, required this.url});

  final String id;
  String url;
  String title = '新标签页';
  bool isLoading = false;

  /// 最后浏览快照（PNG 字节），标签切换页展示。
  Uint8List? snapshot;
}

/// 多标签管理器：维护标签列表与当前激活标签。
class TabManager extends ChangeNotifier {
  static const int maxTabs = 8;

  final List<BrowserTab> _tabs = [];
  String _activeTabId = '';
  int _nextId = 1;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  String get activeTabId => _activeTabId;
  int get count => _tabs.length;

  BrowserTab? get activeTab {
    for (final t in _tabs) {
      if (t.id == _activeTabId) return t;
    }
    return null;
  }

  bool get canAddMore => _tabs.length < maxTabs;

  BrowserTab addTab({String url = 'https://www.baidu.com'}) {
    final tab = BrowserTab(id: 'tab-${_nextId++}', url: url);
    _tabs.add(tab);
    _activeTabId = tab.id;
    notifyListeners();
    return tab;
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeTabId = '';
    } else if (_activeTabId == id) {
      _activeTabId = _tabs[index.clamp(0, _tabs.length - 1)].id;
    }
    notifyListeners();
  }

  void switchTab(String id) {
    if (_activeTabId == id) return;
    _activeTabId = id;
    notifyListeners();
  }

  void updateTab(String id, {String? url, String? title, bool? isLoading}) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (isLoading != null) tab.isLoading = isLoading;
    notifyListeners();
  }

  /// 快照已更新（数据由调用方写入 BrowserTab.snapshot）。
  void notifySnapshotUpdated() => notifyListeners();
}
