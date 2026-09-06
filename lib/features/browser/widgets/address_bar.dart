import 'package:flutter/material.dart';

/// 顶部地址栏：输入网址/搜索词，右侧刷新按钮。
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: onSubmit,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText: '输入网址或搜索内容',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(
            Icons.lock_outline,
            size: 15,
            color: Color(0xFF9CA3AF),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: const Color(0xFF6B7280),
            onPressed: onReload,
            tooltip: '刷新',
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
