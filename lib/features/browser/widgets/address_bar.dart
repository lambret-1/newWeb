import 'package:flutter/material.dart';

import 'site_security_sheet.dart';

/// 顶部地址栏：iOS 风格，左侧安全锁头可点击，右侧刷新按钮。
class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onReload,
    required this.securityLevel,
    required this.isLoading,
    required this.isTabLocked,
    required this.onTapLock,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onReload;
  final SecurityLevel securityLevel;
  final bool isLoading;
  final bool isTabLocked;
  final VoidCallback onTapLock;

  /// 锁头图标颜色。
  Color get _lockColor {
    switch (securityLevel) {
      case SecurityLevel.secure:
        return const Color(0xFF34C759);
      case SecurityLevel.weak:
      case SecurityLevel.mixed:
      case SecurityLevel.insecure:
        return const Color(0xFFFF9500);
      case SecurityLevel.danger:
        return const Color(0xFFFF3B30);
    }
  }

  /// 锁头图标。
  IconData get _lockIcon {
    if (isLoading) return Icons.refresh;
    switch (securityLevel) {
      case SecurityLevel.secure:
        return Icons.lock;
      case SecurityLevel.weak:
        return Icons.lock_outline;
      case SecurityLevel.mixed:
      case SecurityLevel.insecure:
        return Icons.warning_amber;
      case SecurityLevel.danger:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F2F7),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧安全锁头（可点击）
            GestureDetector(
              onTap: onTapLock,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _lockIcon,
                      size: 14,
                      color: _lockColor,
                    ),
                    // 加载中旋转动画
                    if (isLoading)
                      const Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ),
                    // 标签锁定角标
                    if (isTabLocked)
                      const Positioned(
                        right: -4,
                        top: -4,
                        child: Icon(
                          Icons.lock,
                          size: 8,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 输入框
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: onSubmit,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1C1C1E),
                  height: 1.2,
                ),
                decoration: const InputDecoration(
                  hintText: '搜索或输入网址',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            // 右侧刷新按钮
            GestureDetector(
              onTap: onReload,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
