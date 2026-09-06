import 'package:flutter/material.dart';

import '../tab_manager.dart';

/// 标签切换页：网格展示所有标签（含最后浏览快照），支持切换 / 关闭 / 新建。
class TabSwitcherPage extends StatelessWidget {
  const TabSwitcherPage({
    super.key,
    required this.manager,
    required this.onNewTab,
  });

  final TabManager manager;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          '标签页（${manager.count}）',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新建标签页',
            onPressed: onNewTab,
          ),
        ],
      ),
      body: manager.tabs.isEmpty
          ? const Center(
              child: Text(
                '暂无标签页',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            )
          : ListenableBuilder(
              listenable: manager,
              builder: (context, _) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: manager.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = manager.tabs[index];
                    final active = tab.id == manager.activeTabId;
                    return _TabCard(
                      tab: tab,
                      active: active,
                      onTap: () => Navigator.of(context).pop(tab.id),
                      onClose: () => manager.closeTab(tab.id),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFE8F0FE) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: tab.snapshot != null
                            ? Image.memory(
                                tab.snapshot!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                gaplessPlayback: true,
                              )
                            : Container(
                                color: const Color(0xFFEFF4FF),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.public,
                                        size: 30,
                                        color: Color(0xFFB6C2D9),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _initial(tab.title),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
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
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (active)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tab.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
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
