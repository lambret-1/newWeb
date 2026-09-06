import 'package:flutter/material.dart';

import '../../core/services/offline_service.dart';

/// 离线页面列表：打开 / 删除已保存的离线页面（打开时 pop 返回文件路径）。
class OfflinePagesPage extends StatefulWidget {
  const OfflinePagesPage({super.key});

  @override
  State<OfflinePagesPage> createState() => _OfflinePagesPageState();
}

class _OfflinePagesPageState extends State<OfflinePagesPage> {
  List<OfflinePage> _pages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await OfflineService.instance.list();
    if (!mounted) return;
    setState(() {
      _pages = list;
      _loading = false;
    });
  }

  Future<void> _delete(OfflinePage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除离线页面'),
        content: Text('确定删除「${page.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await OfflineService.instance.delete(page);
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
          '离线页面',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _pages.isEmpty
              ? const Center(
                  child: Text(
                    '暂无离线页面\n可在菜单中「保存离线页面」',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  itemCount: _pages.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 68,
                    color: Color(0xFFEDEFF3),
                  ),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(page.path),
                      onLongPress: () => _delete(page),
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.offline_pin_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        page.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${page.sizeText} · ${_formatTime(page.modifiedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () => _delete(page),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
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
