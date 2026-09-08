import 'package:flutter/material.dart';

/// 顶部地址栏：iOS 风格，输入网址/搜索词，右侧刷新按钮。
class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onReload,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onReload;

  /// 根据 URL 判断是否 HTTPS，显示对应图标。
  bool get _isHttps {
    final text = controller.text.trim();
    return text.startsWith('https://');
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
            // 左侧图标：HTTPS 锁 / 普通搜索
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Icon(
                _isHttps ? Icons.lock : Icons.search,
                size: 14,
                color: _isHttps
                    ? const Color(0xFF34C759)
                    : const Color(0xFF8E8E93),
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
