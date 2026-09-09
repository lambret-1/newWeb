import 'dart:async';

import 'package:flutter/material.dart';

/// 手势层：叠加在 WebView 之上，观察式识别手势（不消费触摸，与页面滚动共存）：
/// - 左边缘右滑 → 返回；右边缘左滑 → 前进（阈值 60pt / 0.7s）
/// - 页面顶部轻下拉 → 聚焦地址栏
class GestureLayer extends StatefulWidget {
  const GestureLayer({
    super.key,
    required this.child,
    required this.onEdgeBack,
    required this.onEdgeForward,
    required this.isAtTop,
    this.onPullToFocus,
    this.onTapPage,
  });

  final Widget child;
  final VoidCallback onEdgeBack;
  final VoidCallback onEdgeForward;

  /// 查询当前页面是否在顶部（供下拉聚焦判定）。
  final Future<bool> Function() isAtTop;

  /// 页面顶部轻下拉时触发（用于聚焦地址栏）。
  final VoidCallback? onPullToFocus;

  /// 点击页面非边缘区域时触发（用于让地址栏失焦）。
  final VoidCallback? onTapPage;

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> {
  static const double _edgeWidth = 28;
  static const double _edgeThreshold = 60;
  static const Duration _edgeMaxDuration = Duration(milliseconds: 700);
  static const double _pullFocusThreshold = 80;

  Offset? _downPosition;
  DateTime? _downTime;
  bool _edgeStartAtLeft = false;
  bool _edgeStartAtRight = false;
  bool _pullAtTop = false;

  void _onPointerDown(PointerDownEvent event) {
    final size = context.size;
    if (size == null) return;
    final local = event.localPosition;

    _downPosition = local;
    _downTime = DateTime.now();
    _edgeStartAtLeft = local.dx <= _edgeWidth;
    _edgeStartAtRight = local.dx >= size.width - _edgeWidth;

    // 进入触摸时异步查询页面位置（供下拉聚焦判定）
    if (!_edgeStartAtLeft && !_edgeStartAtRight) {
      unawaited(
        widget.isAtTop().then((value) {
          if (mounted) _pullAtTop = value;
        }),
      );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // 不需要跟踪下拉距离（移除了下拉刷新指示器）
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    final start = _downPosition;
    final startTime = _downTime;
    if (start == null || startTime == null) return;

    final delta = event.localPosition - start;
    final duration = DateTime.now().difference(startTime);

    // 1. 边缘手势：返回 / 前进
    if (_edgeStartAtLeft &&
        delta.dx > _edgeThreshold &&
        delta.dx.abs() > delta.dy.abs() &&
        duration <= _edgeMaxDuration) {
      widget.onEdgeBack();
    } else if (_edgeStartAtRight &&
        delta.dx < -_edgeThreshold &&
        delta.dx.abs() > delta.dy.abs() &&
        duration <= _edgeMaxDuration) {
      widget.onEdgeForward();
    }

    // 2. 顶部轻下拉聚焦地址栏（30-80pt）
    if (!_edgeStartAtLeft &&
        !_edgeStartAtRight &&
        _pullAtTop &&
        delta.dy > 30 &&
        delta.dy <= _pullFocusThreshold &&
        delta.dy.abs() > delta.dx.abs()) {
      widget.onPullToFocus?.call();
    } else if (!_edgeStartAtLeft &&
        !_edgeStartAtRight &&
        delta.distance < 10) {
      // 轻触页面（非边缘、非下拉）：通知外部让地址栏失焦
      widget.onTapPage?.call();
    }

    _downPosition = null;
    _downTime = null;
    _pullAtTop = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) {
              _downPosition = null;
              _downTime = null;
              _pullAtTop = false;
            },
          ),
        ),
      ],
    );
  }
}
