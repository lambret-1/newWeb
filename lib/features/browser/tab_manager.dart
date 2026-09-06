
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    unawaited(saveSession());
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
    unawaited(saveSession());
  }

  void updateTab(String id, {String? url, String? title, bool? isLoading}) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (isLoading != null) tab.isLoading = isLoading;
    notifyListeners();
    unawaited(saveSession());
  }

  /// 快照已更新（数据由调用方写入 BrowserTab.snapshot）。
  void notifySnapshotUpdated() => notifyListeners();

  // ---- 会话持久化（退出应用后恢复标签） ----

  static const String _sessionKey = 'tab_session_v1';

  /// 是否持久化会话（无痕模式为 false）。
  bool persistSession = true;

  /// 设置会话持久化开关（无痕模式关闭持久化并清除已存会话）。
  Future<void> setPersistSession(bool value) async {
    persistSession = value;
    if (!value) await clearSession();
  }

  /// 保存当前标签会话（URL / 标题 / 激活项）。无痕模式下不保存。
  Future<void> saveSession() async {
    if (!persistSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'tabs': _tabs
              .map((t) => {'url': t.url, 'title': t.title})
              .toList(),
          'activeIndex': _tabs.indexWhere((t) => t.id == _activeTabId),
        }),
      );
    } catch (_) {}
  }

  /// 恢复上次会话；成功返回 true（有标签可恢复）。
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tabs = (data['tabs'] as List? ?? []).cast<Map<String, dynamic>>();
      if (tabs.isEmpty) return false;
      _tabs.clear();
      for (final t in tabs) {
        final url = (t['url'] as String? ?? '').trim();
        final tab = BrowserTab(
          id: 'tab-${_nextId++}',
          url: url.isEmpty ? 'https://www.baidu.com' : url,
        );
        final title = t['title'] as String?;
        if (title != null && title.isNotEmpty) tab.title = title;
        _tabs.add(tab);
      }
      final activeIndex = (data['activeIndex'] as num?)?.toInt() ?? 0;
      _activeTabId = _tabs[activeIndex.clamp(0, _tabs.length - 1)].id;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 是否已保存过会话。
  Future<bool> hasSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      return raw != null && raw.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 清除已保存会话（无痕模式）。
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }
}
