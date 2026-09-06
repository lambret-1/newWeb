import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/history_entry.dart';

/// 历史记录页：按时间倒序展示，支持打开 / 清空。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.getHistory();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定删除全部浏览历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.clearHistory();
    _load();
  }

  String _formatTime(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
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
          '历史记录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _clear,
              child: const Text(
                '清空',
                style: TextStyle(color: Color(0xFFEA6668), fontSize: 14),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    '暂无浏览历史',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 68,
                    color: Color(0xFFEDEFF3),
                  ),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(entry.url),
                      leading: _Favicon(title: entry.title),
                      title: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        entry.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: Text(
                        _formatTime(entry.visitedAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0B7C3)),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Favicon extends StatelessWidget {
  const _Favicon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = title.trim();
    final initial = t.isEmpty ? '网' : t.characters.first.toUpperCase();
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
