import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/bookmark.dart';

/// 书签页：查看 / 打开 / 删除书签（打开时 pop 返回 url）。
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<Bookmark> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DatabaseHelper.instance.initDefaultBookmarks();
    final list = await DatabaseHelper.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks = list;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '书签',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _bookmarks.isEmpty
              ? const Center(
                  child: Text(
                    '暂无书签，可在菜单中「添加到书签」',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  itemCount: _bookmarks.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 68, color: Color(0xFFEDEFF3)),
                  itemBuilder: (context, index) {
                    final bookmark = _bookmarks[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(bookmark.url),
                      onLongPress: () => _delete(bookmark),
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
                        onTap: () => _delete(bookmark),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            size: 16,
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
