import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 底部工具栏：后退 / 前进 / 分享 / 标签页（显示数量） / 更多。
/// 可用状态显示 iOS 蓝色，不可用状态显示灰色。
class ToolBar extends StatelessWidget {
  const ToolBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onShare,
    required this.onTabs,
    required this.onMore,
    required this.tabCount,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onShare;
  final VoidCallback onTabs;
  final VoidCallback onMore;
  final int tabCount;

  @override
  Widget build(BuildContext context) {
    const enabledColor = Color(0xFF007AFF); // iOS 系统蓝
    const disabledColor = Color(0xFFC7C7CC); // iOS 不可用灰

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
              iconSize: 24,
              onPressed: onShare,
              icon: const Icon(CupertinoIcons.share),
              color: enabledColor,
              tooltip: '分享',
            ),
            IconButton(
              iconSize: 22,
              onPressed: onTabs,
              icon: _TabCountIcon(count: tabCount, color: enabledColor),
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

/// Chrome 风格标签计数图标：圆角方框 + 居中数字。
class _TabCountIcon extends StatelessWidget {
  const _TabCountIcon({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color, width: 1.6),
            ),
          ),
          Text(
            count > 99 ? '99+' : '$count',
            style: TextStyle(
              fontSize: count > 9 ? 9 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
