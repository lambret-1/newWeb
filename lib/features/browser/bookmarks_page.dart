import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/bookmark.dart';

/// 书签页：搜索 / 打开 / 编辑 / 删除 / 分享书签。
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Bookmark> _bookmarks = [];
  List<Bookmark> _filtered = [];
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
    await DatabaseHelper.instance.initDefaultBookmarks();
    final list = await DatabaseHelper.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks = list;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = _bookmarks;
    } else {
      _filtered = _bookmarks
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.url.toLowerCase().contains(q))
          .toList();
    }
  }

  Future<void> _delete(Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书签'),
        content: Text('确定删除「${bookmark.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteBookmark(bookmark.id!);
    _load();
  }

  Future<void> _edit(Bookmark bookmark) async {
    final titleController = TextEditingController(text: bookmark.title);
    final urlController = TextEditingController(text: bookmark.url);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑书签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '网址',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final title = titleController.text.trim();
    final url = urlController.text.trim();
    if (title.isEmpty || url.isEmpty) return;
    await DatabaseHelper.instance.updateBookmark(bookmark.id!, title, url);
    _load();
  }

  void _showActions(Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Color(0xFF3B82F6)),
              title: const Text('打开'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(bookmark.url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF374151)),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(ctx).pop();
                _edit(bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF374151)),
              title: const Text('分享'),
              onTap: () {
                Navigator.of(ctx).pop();
                Share.share(bookmark.url, subject: bookmark.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFEA6668)),
              title: const Text('删除', style: TextStyle(color: Color(0xFFEA6668))),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(bookmark);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '搜索书签',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFFB0B7C3)),
                ),
                onChanged: (_) => setState(_applyFilter),
              )
            : const Text(
                '书签',
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _filtered.isEmpty
              ? Center(
                  child: Text(
                    _searching ? '未找到匹配的书签' : '暂无书签，可在菜单中「添加到书签」',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 68, color: Color(0xFFEDEFF3)),
                  itemBuilder: (context, index) {
                    final bookmark = _filtered[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(bookmark.url),
                      onLongPress: () => _showActions(bookmark),
                      leading: _Favicon(title: bookmark.title),
                      title: Text(
                        bookmark.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        bookmark.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: GestureDetector(
                        onTap: () => _showActions(bookmark),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.more_horiz,
                            size: 20,
                            color: Color(0xFFB0B7C3),
                          ),
                        ),
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
