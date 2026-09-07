import 'dart:io';

import '../../../core/services/debug_logger.dart';
import 'package:flutter/material.dart';

import '../tab_manager.dart';

/// 标签切换页：网格展示所有标签（含最后浏览快照），支持切换 / 关闭 / 新建 / 批量选择。
class TabSwitcherPage extends StatefulWidget {
  const TabSwitcherPage({
    super.key,
    required this.manager,
    required this.onNewTab,
    required this.onCloseSelected,
    required this.onBookmarkSelected,
  });

  final TabManager manager;
  final VoidCallback onNewTab;

  /// 批量关闭选中标签（ids 为空时关闭全部）。
  final void Function(List<String> ids) onCloseSelected;

  /// 批量添加选中标签到书签。
  final void Function(List<String> ids) onBookmarkSelected;

  @override
  State<TabSwitcherPage> createState() => _TabSwitcherPageState();
}

class _TabSwitcherPageState extends State<TabSwitcherPage> {
  bool _selectMode = false;
  final Set<String> _selected = {};

  bool get _allSelected =>
      _selected.length == widget.manager.tabs.length &&
      widget.manager.tabs.isNotEmpty;

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(widget.manager.tabs.map((t) => t.id));
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  Future<void> _closeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭所有标签页？'),
        content: Text('将关闭全部 ${widget.manager.count} 个标签页，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('全部关闭', style: TextStyle(color: Color(0xFFEA6668))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onCloseSelected([]);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showModifyMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF3B82F6)),
              title: const Text('选择标签页'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() => _selectMode = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEA6668)),
              title: const Text('关闭所有标签页'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _closeAll();
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
      backgroundColor: Colors.black,
      appBar: _selectMode ? _buildSelectAppBar() : _buildNormalAppBar(),
      body: widget.manager.tabs.isEmpty
          ? const Center(
              child: Text(
                '暂无标签页',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            )
          : ListenableBuilder(
              listenable: widget.manager,
              builder: (context, _) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: widget.manager.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = widget.manager.tabs[index];
                    final active = tab.id == widget.manager.activeTabId;
                    final selected = _selected.contains(tab.id);
                    return _TabCard(
                      tab: tab,
                      active: active,
                      selectMode: _selectMode,
                      selected: selected,
                      onTap: () {
                        if (_selectMode) {
                          _toggleSelect(tab.id);
                        } else {
                          Navigator.of(context).pop(tab.id);
                        }
                      },
                      onClose: () => widget.manager.closeTab(tab.id),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: _selectMode ? _buildBatchBar() : _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F6F8),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        '标签页（${widget.manager.count}）',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      ),
    );
  }

  PreferredSizeWidget _buildSelectAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F6F8),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: TextButton(
        onPressed: _toggleSelectAll,
        child: Text(
          _allSelected ? '取消全选' : '全选',
          style: const TextStyle(fontSize: 15, color: Color(0xFF3B82F6)),
        ),
      ),
      leadingWidth: 90,
      centerTitle: true,
      title: Text(
        '已选 ${_selected.length} 个',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      ),
      actions: [
        TextButton(
          onPressed: _exitSelectMode,
          child: const Text(
            '完成',
            style: TextStyle(fontSize: 15, color: Color(0xFF3B82F6)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _showModifyMenu,
                child: const Text(
                  '修改',
                  style: TextStyle(fontSize: 16, color: Color(0xFF374151)),
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onNewTab,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Color(0xFFF5F6F8), size: 28),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '完成',
                  style: TextStyle(fontSize: 16, color: Color(0xFF374151)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchBar() {
    final hasSelection = _selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Color(0xFFF5F6F8),
          border: const Border(top: BorderSide(color: Color(0xFF2C2C2E))),
          boxShadow: hasSelection
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: hasSelection
                    ? () {
                        widget.onCloseSelected(_selected.toList());
                        _exitSelectMode();
                      }
                    : null,
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF9CA3AF)),
                label: Text(
                  hasSelection ? '关闭 ${_selected.length} 个' : '关闭标签',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasSelection
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
            Expanded(
              child: TextButton.icon(
                onPressed: hasSelection
                    ? () {
                        widget.onBookmarkSelected(_selected.toList());
                        _exitSelectMode();
                      }
                    : null,
                icon: const Icon(Icons.star_border, size: 20, color: Color(0xFF9CA3AF)),
                label: Text(
                  hasSelection ? '添加 ${_selected.length} 个书签' : '添加到书签',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasSelection
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.active,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool active;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF3B82F6) : (active ? const Color(0xFF3B82F6) : Colors.transparent);
    final borderWidth = (selected || active) ? 2.5 : 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildSnapshot(),
                        ),
                      ),
                      // 选择模式：右上角蓝色圆圈
                      if (selectMode)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF3B82F6),
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      // 普通模式：右上角关闭按钮
                      if (!selectMode)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: onClose,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tab.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshot() {
    // 优先读磁盘快照，其次内存快照，最后占位
    if (tab.snapshotPath != null) {
      final exists = File(tab.snapshotPath!).existsSync();
      DebugLogger.instance.log(' 卡片 tabId=${tab.id}, snapshotPath=${tab.snapshotPath}, 文件存在=$exists');
      if (exists) {
        return Image.file(
          File(tab.snapshotPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
        );
      }
    }
    if (tab.snapshot != null) {
      DebugLogger.instance.log(' 卡片 tabId=${tab.id}, 使用内存快照, bytes=${tab.snapshot!.length}');
      return Image.memory(
        tab.snapshot!,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
      );
    }
    DebugLogger.instance.log(' 卡片 tabId=${tab.id}, ❌ 无任何快照，显示占位');
    return Container(
      color: const Color(0xFFEFF4FF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 28, color: Color(0xFFB6C2D9)),
            const SizedBox(height: 4),
            Text(
              _initial(tab.title),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String title) {
    final t = title.trim();
    if (t.isEmpty) return '网';
    return t.characters.first.toUpperCase();
  }
}
