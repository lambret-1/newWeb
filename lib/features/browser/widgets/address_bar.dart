import 'package:flutter/material.dart';

import 'site_security_sheet.dart';

/// 顶部地址栏（增强版）：域名高亮、一键清空、长按菜单、滑动前进后退、搜索引擎切换。
class AddressBar extends StatefulWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onReload,
    required this.securityLevel,
    required this.isLoading,
    required this.isTabLocked,
    required this.onTapLock,
    required this.currentUrl,
    required this.onGoBack,
    required this.onGoForward,
    required this.canGoBack,
    required this.canGoForward,
    required this.searchEngine,
    required this.onSwitchSearchEngine,
    required this.onFocusChanged,
    this.focusNode,
    this.visible = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onReload;
  final SecurityLevel securityLevel;
  final bool isLoading;
  final bool isTabLocked;
  final VoidCallback onTapLock;
  final String currentUrl;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final bool canGoBack;
  final bool canGoForward;
  final String searchEngine;
  final ValueChanged<String> onSwitchSearchEngine;
  final ValueChanged<bool> onFocusChanged;
  final FocusNode? focusNode;
  final bool visible;

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    widget.onFocusChanged(_focusNode.hasFocus);
    // 聚焦时同步 controller 文本为当前 URL
    if (_focusNode.hasFocus) {
      final current = widget.currentUrl;
      if (current.isNotEmpty && current != 'about:blank') {
        widget.controller.text = current;
      }
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    }
  }

  void _onTextChanged() {
    if (_hasText != widget.controller.text.isNotEmpty) {
      setState(() => _hasText = widget.controller.text.isNotEmpty);
    }
  }

  /// 域名高亮：解析 URL，主域名加粗，协议/路径灰色。
  Widget _buildDomainHighlight() {
    final url = widget.currentUrl;
    if (url.isEmpty || url == 'about:blank') {
      return const Text(
        '搜索或输入网址',
        style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
      );
    }
    try {
      final uri = Uri.parse(url);
      final scheme = uri.hasScheme ? '${uri.scheme}://' : '';
      final host = uri.host;
      final path = uri.path == '/' ? '' : uri.path;
      final query = uri.query.isEmpty ? '' : '?${uri.query}';
      return Text.rich(
        TextSpan(
          children: [
            if (scheme.isNotEmpty)
              TextSpan(
                text: scheme,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            TextSpan(
              text: host,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            if (path.isNotEmpty)
              TextSpan(
                text: path,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            if (query.isNotEmpty)
              TextSpan(
                text: query,
                style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } catch (_) {
      return Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
      );
    }
  }

  Color get _lockColor {
    switch (widget.securityLevel) {
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

  IconData get _lockIcon {
    // 加载中不显示锁头图标，只显示进度圈
    if (widget.isLoading) return Icons.refresh;
    switch (widget.securityLevel) {
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

  /// 搜索引擎快速切换菜单。
  void _showSearchEngineMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 5,
                decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择搜索引擎（本次搜索生效）', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
              ),
            ),
            _menuItem(Icons.search, '百度', () {
              Navigator.pop(ctx);
              widget.onSwitchSearchEngine('baidu');
            }, selected: widget.searchEngine == 'baidu'),
            _menuItem(Icons.search, '必应', () {
              Navigator.pop(ctx);
              widget.onSwitchSearchEngine('bing');
            }, selected: widget.searchEngine == 'bing'),
            _menuItem(Icons.search, 'Google', () {
              Navigator.pop(ctx);
              widget.onSwitchSearchEngine('google');
            }, selected: widget.searchEngine == 'google'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool selected = false}) {
    return ListTile(
      leading: Icon(icon, size: 20, color: selected ? const Color(0xFF007AFF) : const Color(0xFF3C3C43)),
      title: Text(label, style: TextStyle(fontSize: 15, color: selected ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E))),
      trailing: selected ? const Icon(Icons.check, size: 18, color: Color(0xFF007AFF)) : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return GestureDetector(
      // 左右滑动前进后退（仅非输入态）
      onHorizontalDragEnd: _isFocused ? null : (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 300 && widget.canGoBack) {
          widget.onGoBack();
        } else if (details.primaryVelocity! < -300 && widget.canGoForward) {
          widget.onGoForward();
        }
      },
      child: Container(
        color: const Color(0xFFF2F2F7),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: _isFocused ? Border.all(color: const Color(0xFF007AFF), width: 1.5) : null,
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
              // 左侧安全锁头
              GestureDetector(
                onTap: widget.onTapLock,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (widget.isLoading)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF007AFF)),
                        )
                      else
                        Icon(_lockIcon, size: 14, color: _lockColor),
                      if (widget.isTabLocked)
                        const Positioned(
                          right: -4, top: -4,
                          child: Icon(Icons.lock, size: 8, color: Color(0xFFFF9500)),
                        ),
                    ],
                  ),
                ),
              ),
              // 搜索引擎切换按钮（仅输入态显示）
              if (_isFocused)
                GestureDetector(
                  onTap: _showSearchEngineMenu,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.tune, size: 14, color: Color(0xFF007AFF)),
                  ),
                ),
              // 输入框 / 域名高亮
              Expanded(
                child: _isFocused
                    ? TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: widget.onSubmit,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E), height: 1.2),
                        decoration: const InputDecoration(
                          hintText: '搜索或输入网址',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          // 先切换到输入态显示 TextField，下一帧再请求焦点
                          // 否则 focusNode 没有绑定的输入框，无法获得焦点
                          setState(() => _isFocused = true);
                          widget.onFocusChanged(true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _focusNode.requestFocus();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildDomainHighlight(),
                        ),
                      ),
              ),
              // 一键清空（输入态且有内容）
              if (_isFocused && _hasText)
                GestureDetector(
                  onTap: () => widget.controller.clear(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.cancel, size: 16, color: Color(0xFFC7C7CC)),
                  ),
                ),
              // 右侧刷新按钮（非输入态）
              if (!_isFocused)
                GestureDetector(
                  onTap: widget.onReload,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.refresh, size: 16, color: Color(0xFF007AFF)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
