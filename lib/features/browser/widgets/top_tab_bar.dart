import 'package:flutter/material.dart';

import '../tab_manager.dart';

/// 顶部标签栏：低高度横向滚动，点击切换，长按编辑/锁定/关闭。
class TopTabBar extends StatelessWidget {
  final TabManager tabManager;
  final void Function(String tabId) onSwitch;
  final void Function(String tabId) onClose;
  final void Function(String tabId, String newTitle) onEditTitle;
  final void Function(String tabId, String newUrl) onEditUrl;
  final void Function(String tabId, bool locked) onToggleLock;
  final VoidCallback onAdd;

  const TopTabBar({
    super.key,
    required this.tabManager,
    required this.onSwitch,
    required this.onClose,
    required this.onEditTitle,
    required this.onEditUrl,
    required this.onToggleLock,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = tabManager.tabs;
    final activeId = tabManager.activeTabId;

    return Container(
      height: 34,
      color: const Color(0xFFF2F2F7),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = tab.id == activeId;
                return _TabItem(
                  title: tab.displayName,
                  isActive: isActive,
                  isLocked: tab.isLocked,
                  onTap: () => onSwitch(tab.id),
                  onLongPress: () => _showTabMenu(context, tab),
                  onClose: tab.isLocked ? null : () => onClose(tab.id),
                );
              },
            ),
          ),
          // 新建标签按钮
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 18, color: Color(0xFF007AFF)),
            ),
          ),
        ],
      ),
    );
  }

  /// 长按弹出操作菜单：编辑标题 / 编辑网址 / 锁定解锁 / 关闭标签。
  void _showTabMenu(BuildContext context, BrowserTab tab) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, size: 20, color: Color(0xFF007AFF)),
              title: const Text('编辑标题', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditTitleDialog(context, tab);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, size: 20, color: Color(0xFF007AFF)),
              title: const Text('编辑网址', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditUrlDialog(context, tab);
              },
            ),
            ListTile(
              leading: Icon(
                tab.isLocked ? Icons.lock_open : Icons.lock_outline,
                size: 20,
                color: const Color(0xFF007AFF),
              ),
              title: Text(
                tab.isLocked ? '解锁标签' : '锁定标签',
                style: const TextStyle(fontSize: 15),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onToggleLock(tab.id, !tab.isLocked);
              },
            ),
            if (!tab.isLocked)
              ListTile(
                leading: const Icon(Icons.close, size: 20, color: Color(0xFFFF3B30)),
                title: const Text('关闭标签',
                    style: TextStyle(fontSize: 15, color: Color(0xFFFF3B30))),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onClose(tab.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel, size: 20, color: Color(0xFF8E8E93)),
              title: const Text('取消', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// 编辑标签标题弹窗。
  void _showEditTitleDialog(BuildContext context, BrowserTab tab) {
    final controller = TextEditingController(text: tab.customTitle ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑标签标题', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '留空则显示主域名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onEditTitle(tab.id, '');
              Navigator.of(dialogContext).pop();
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              onEditTitle(tab.id, newTitle);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 编辑标签网址弹窗。
  void _showEditUrlDialog(BuildContext context, BrowserTab tab) {
    final controller = TextEditingController(text: tab.url);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑标签网址', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: '输入新网址',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              var newUrl = controller.text.trim();
              if (newUrl.isEmpty) return;
              if (!newUrl.startsWith('http')) {
                newUrl = 'https://$newUrl';
              }
              onEditUrl(tab.id, newUrl);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }
}

/// 单个标签项。
class _TabItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onClose;

  const _TabItem({
    required this.title,
    required this.isActive,
    required this.isLocked,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: const Color(0xFF007AFF), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLocked) ...[
              const Icon(Icons.lock, size: 11, color: Color(0xFFFF9500)),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? const Color(0xFF000000) : const Color(0xFF8E8E93),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: isActive ? const Color(0xFF8E8E93) : const Color(0xFFC7C7CC),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
