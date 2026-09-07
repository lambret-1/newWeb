import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/history_entry.dart';

/// 历史记录页：按日期分组 / 搜索 / 打开 / 单条删除 / 清空。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _entries = [];
  List<HistoryEntry> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.getHistory();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = _entries;
    } else {
      _filtered = _entries
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.url.toLowerCase().contains(q))
          .toList();
    }
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

  Future<void> _deleteEntry(HistoryEntry entry) async {
    if (entry.id == null) return;
    await DatabaseHelper.instance.deleteHistoryEntry(entry.id!);
    _load();
  }

  /// 按日期分组：返回 (组标题, 条目列表) 的有序列表。
  List<MapEntry<String, List<HistoryEntry>>> _groupByDate(
      List<HistoryEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.visitedAt);
      final d = DateTime(t.year, t.month, t.day);
      String key;
      if (d == today) {
        key = '今天';
      } else if (d == yesterday) {
        key = '昨天';
      } else if (now.difference(d).inDays < 7) {
        key = '本周';
      } else if (t.year == now.year) {
        key = '${t.month}月${t.day}日';
      } else {
        key = '${t.year}年${t.month}月';
      }
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups.entries.toList();
  }

  String _formatTime(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '搜索历史记录',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFFB0B7C3)),
                ),
                onChanged: (_) => setState(_applyFilter),
              )
            : const Text(
                '历史记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, size: 22),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _applyFilter();
                }
              });
            },
          ),
          if (_entries.isNotEmpty && !_searching)
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
          : _filtered.isEmpty
              ? Center(
                  child: Text(
                    _searching ? '未找到匹配的记录' : '暂无浏览历史',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                )
              : ListView(
                  children: _groupByDate(_filtered).map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            group.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        ...group.value.map((entry) => _buildEntry(entry)),
                      ],
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildEntry(HistoryEntry entry) {
    return Dismissible(
      key: ValueKey('hist-${entry.id ?? entry.url}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFEA6668),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteEntry(entry),
      child: Container(
        color: Colors.white,
        child: ListTile(
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
        ),
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
