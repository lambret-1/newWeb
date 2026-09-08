
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 浏览器标签元数据（WebViewController 由各 WebViewPage 内部持有）。
class BrowserTab {
  BrowserTab({required this.id, required this.url});

  final String id;
  String url;
  String title = '新标签页';
  bool isLoading = false;

  /// 用户自定义标签标题（为 null 时显示主域名）。
  String? customTitle;

  /// 是否锁定：锁定后不可关闭。
  bool isLocked = false;

  /// 最后浏览快照（PNG 字节，内存缓存），标签切换页展示。
  Uint8List? snapshot;

  /// 快照磁盘文件路径（持久化，App 重启后仍可读）。
  String? snapshotPath;

  /// 页面滚动位置 Y（离开标签时保存，重建后恢复）。
  double scrollY = 0;

  /// 最近使用时间戳（LRU 排序用）。
  int lastUsed = DateTime.now().millisecondsSinceEpoch;

  /// 从 URL 提取主域名（如 https://www.baidu.com/s?wd=1 → baidu.com）。
  String get displayDomain {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return url;
      // 去掉 www. 前缀
      final domain = host.startsWith('www.') ? host.substring(4) : host;
      return domain;
    } catch (_) {
      return url;
    }
  }

  /// 标签显示名称：自定义标题优先，否则显示主域名。
  String get displayName => customTitle ?? displayDomain;
}

/// 多标签管理器：维护标签列表与当前激活标签。
class TabManager extends ChangeNotifier {
  static const int maxTabs = 8;

  /// LRU 保活上限：同时最多保留 N 个 WKWebView 实例在内存。
  static const int keepAliveCount = 6;

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

  /// LRU：返回需要保活 WKWebView 的标签 id（最近使用的 N 个）。
  Set<String> get keepAliveTabIds {
    final sorted = [..._tabs]
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return sorted.take(keepAliveCount).map((t) => t.id).toSet();
  }

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
    final tab = _tabs[index];
    _tabs.removeAt(index);
    // 删除磁盘快照
    if (tab.snapshotPath != null) {
      try {
        File(tab.snapshotPath!).deleteSync();
      } catch (_) {}
    }
    if (_tabs.isEmpty) {
      _activeTabId = '';
    } else if (_activeTabId == id) {
      _activeTabId = _tabs[index.clamp(0, _tabs.length - 1)].id;
    }
    notifyListeners();
    unawaited(saveSession());
  }

  void switchTab(String id) {
    if (_activeTabId == id) return;
    _activeTabId = id;
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab != null) tab.lastUsed = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(saveSession());
  }

  void updateTab(String id,
      {String? url, String? title, bool? isLoading, double? scrollY}) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (isLoading != null) tab.isLoading = isLoading;
    if (scrollY != null) tab.scrollY = scrollY;
    notifyListeners();
    unawaited(saveSession());
  }

  /// 设置标签锁定状态。
  void setLocked(String id, bool locked) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    tab.isLocked = locked;
    notifyListeners();
    unawaited(saveSession());
  }

  /// 设置用户自定义标签标题（传 null 清除自定义，恢复显示主域名）。
  void setCustomTitle(String id, String? customTitle) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    tab.customTitle = customTitle;
    notifyListeners();
    unawaited(saveSession());
  }

  /// 更新标签快照（内存 + 磁盘路径）。
  void updateSnapshot(String id,
      {Uint8List? bytes, String? diskPath}) {
    final tab = _tabs.where((t) => t.id == id).firstOrNull;
    if (tab == null) return;
    if (bytes != null) tab.snapshot = bytes;
    if (diskPath != null) tab.snapshotPath = diskPath;
    notifyListeners();
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

  /// 保存当前标签会话（URL / 标题 / 滚动位置 / 快照路径 / 激活项）。无痕模式下不保存。
  Future<void> saveSession() async {
    if (!persistSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'tabs': _tabs
              .map((t) => {
                    'url': t.url,
                    'title': t.title,
                    'customTitle': t.customTitle,
                    'isLocked': t.isLocked,
                    'scrollY': t.scrollY,
                    'snapshotPath': t.snapshotPath,
                  })
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
        final customTitle = t['customTitle'] as String?;
        if (customTitle != null && customTitle.isNotEmpty) {
          tab.customTitle = customTitle;
        }
        tab.isLocked = t['isLocked'] as bool? ?? false;
        tab.scrollY = (t['scrollY'] as num?)?.toDouble() ?? 0;
        final snap = t['snapshotPath'] as String?;
        if (snap != null && snap.isNotEmpty && File(snap).existsSync()) {
          tab.snapshotPath = snap;
        }
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
