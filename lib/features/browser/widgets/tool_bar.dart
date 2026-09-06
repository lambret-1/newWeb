import 'package:flutter/material.dart';

/// 底部工具栏：后退 / 前进 / 首页 / 标签页 / 更多。
class ToolBar extends StatelessWidget {
  const ToolBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onTabs,
    required this.onMore,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onTabs;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const enabledColor = Color(0xFF374151);
    const disabledColor = Color(0xFFD1D5DB);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 22,
              onPressed: canGoBack ? onBack : null,
              icon: const Icon(Icons.arrow_back_ios_new),
              color: canGoBack ? enabledColor : disabledColor,
              tooltip: '后退',
            ),
            IconButton(
              iconSize: 22,
              onPressed: canGoForward ? onForward : null,
              icon: const Icon(Icons.arrow_forward_ios),
              color: canGoForward ? enabledColor : disabledColor,
              tooltip: '前进',
            ),
            IconButton(
              iconSize: 22,
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined),
              color: enabledColor,
              tooltip: '首页',
            ),
            IconButton(
              iconSize: 22,
              onPressed: onTabs,
              icon: const Icon(Icons.tab_outlined),
              color: enabledColor,
              tooltip: '标签页',
            ),
            IconButton(
              iconSize: 22,
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz),
              color: enabledColor,
              tooltip: '更多',
            ),
          ],
        ),
      ),
    );
  }
}
