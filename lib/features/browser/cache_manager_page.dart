import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/services/offline_service.dart';
import '../../native/native_bridge.dart';

/// 四级缓存管理：
/// L1 网页缓存（沙盒 Caches + URLCache）
/// L2 网络缓存（WKWebView diskCache + URLCache）
/// L3 Cookie 与站点数据（Cookie / localStorage / IndexedDB / WebSQL）
/// L4 全部数据（全部网站数据 + 离线页面 + 历史记录）
class CacheManagerPage extends StatefulWidget {
  const CacheManagerPage({super.key});

  @override
  State<CacheManagerPage> createState() => _CacheManagerPageState();
}

class _CacheManagerPageState extends State<CacheManagerPage> {
  int _cacheSize = -1;
  int _recordCount = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final size = await NativeBridge.getCacheSize();
    final count = await NativeBridge.getWebDataRecordCount();
    if (!mounted) return;
    setState(() {
      _cacheSize = size;
      _recordCount = count;
    });
  }

  String _fmt(int bytes) {
    if (bytes < 0) return '读取中…';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<bool> _confirm(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清理', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _clear(String level, String title, String message,
      Future<void> Function() action) async {
    if (!await _confirm(title, message)) return;
    setState(() {
      _cacheSize = -1;
      _recordCount = -1;
    });
    await action();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$level 已清理'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '缓存管理',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '共四级缓存，可单独清理或一键清理全部',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
          _level(
            level: 'L1',
            title: '网页缓存',
            desc: '应用沙盒缓存与网络缓存（图片、脚本、样式等）',
            info: _fmt(_cacheSize),
            onClear: () => _clear(
              'L1',
              '清理网页缓存',
              '将清理沙盒 Caches 与网络缓存，不影响登录状态。',
              NativeBridge.clearHttpCache,
            ),
          ),
          _level(
            level: 'L2',
            title: '网络缓存',
            desc: 'WebView 磁盘缓存（diskCache）',
            info: _fmt(_cacheSize),
            onClear: () => _clear(
              'L2',
              '清理网络缓存',
              '将清理 WebView 磁盘缓存与网络缓存。',
              () => NativeBridge.clearWebDataTypes(const ['diskCache']),
            ),
          ),
          _level(
            level: 'L3',
            title: 'Cookie 与站点数据',
            desc: 'Cookie、localStorage、IndexedDB、WebSQL',
            info: _recordCount >= 0 ? '$_recordCount 条记录' : '读取中…',
            onClear: () => _clear(
              'L3',
              '清理站点数据',
              '将清除全部网站的 Cookie 与本地存储，需要重新登录网站。',
              () => NativeBridge.clearWebDataTypes(
                const ['cookies', 'localStorage', 'indexedDB', 'websql'],
              ),
            ),
          ),
          _level(
            level: 'L4',
            title: '全部数据',
            desc: '网站数据 + 离线页面 + 历史记录',
            info: '彻底清理',
            onClear: () => _clear(
              'L4',
              '清理全部数据',
              '将清除全部网站数据、离线页面与浏览历史，不可恢复。',
              _clearAll,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    await NativeBridge.clearWebData();
    await OfflineService.instance.clearAll();
    await DatabaseHelper.instance.clearHistory();
  }

  Widget _level({
    required String level,
    required String title,
    required String desc,
    required String info,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              level,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text(
              '清理',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFEA6668),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
