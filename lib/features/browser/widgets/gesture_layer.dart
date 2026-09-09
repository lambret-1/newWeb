import 'dart:async';

import 'package:flutter/material.dart';

/// 手势层：叠加在 WebView 之上，观察式识别手势（不消费触摸，与页面滚动共存）：
/// - 左边缘右滑 → 返回；右边缘左滑 → 前进（阈值 60pt / 0.7s）
/// - 上半屏顶部下拉 → 下拉刷新（显示自绘指示器）
/// - 上半屏顶部轻下拉 → 聚焦地址栏
class GestureLayer extends StatefulWidget {
  const GestureLayer({
    super.key,
    required this.child,
    required this.onEdgeBack,
    required this.onEdgeForward,
    required this.isAtTop,
    required this.onRefresh,
    this.edgeThreshold = 60,
    this.pullThreshold = 80,
    this.onPullToFocus,
    this.onTapPage,
  });

  final Widget child;
  final VoidCallback onEdgeBack;
  final VoidCallback onEdgeForward;

  /// 查询当前页面是否在顶部（供下拉刷新判定）。
  final Future<bool> Function() isAtTop;
  final Future<void> Function() onRefresh;

  /// 边缘手势触发阈值（pt），值越小越灵敏。
  final double edgeThreshold;

  /// 下拉刷新触发阈值（pt），值越小越灵敏。
  final double pullThreshold;

  /// 页面顶部轻下拉时触发（用于聚焦地址栏），下拉距离小于刷新阈值时调用。
  final VoidCallback? onPullToFocus;

  /// 点击页面非边缘区域时触发（用于让地址栏失焦）。
  final VoidCallback? onTapPage;

  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer> {
  static const double _edgeWidth = 28;
  static const Duration _edgeMaxDuration = Duration(milliseconds: 700);
  static const double _pullMaxDistance = 90;

  Offset? _downPosition;
  DateTime? _downTime;
  bool _edgeStartAtLeft = false;
  bool _edgeStartAtRight = false;

  bool _pullAtTop = false;
  bool _pullInUpperHalf = false;
  double _pullDistance = 0;
  bool _refreshing = false;

  void _onPointerDown(PointerDownEvent event) {
    final size = context.size;
    if (size == null) return;
    final local = event.localPosition;

    _downPosition = local;
    _downTime = DateTime.now();
    _edgeStartAtLeft = local.dx <= _edgeWidth;
    _edgeStartAtRight = local.dx >= size.width - _edgeWidth;
    // 识别区：仅上半屏（触摸起始点 y < 屏幕高度的一半）
    _pullInUpperHalf = local.dy < size.height / 2;
    _pullDistance = 0;

    // 顶部下拉刷新：进入触摸时异步查询页面位置
    if (!_edgeStartAtLeft && !_edgeStartAtRight && _pullInUpperHalf) {
      unawaited(
        widget.isAtTop().then((value) {
          if (mounted) _pullAtTop = value;
        }),
      );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_downPosition == null) return;
    if (!_pullInUpperHalf || _edgeStartAtLeft || _edgeStartAtRight) return;
    final delta = event.localPosition - _downPosition!;
    // 只跟踪下拉位移（dy>0 且纵向占主导）
    if (delta.dy > 0 && delta.dy.abs() > delta.dx.abs()) {
      setState(() {
        _pullDistance = delta.dy.clamp(0, _pullMaxDistance);
      });
    }
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    final start = _downPosition;
    final startTime = _downTime;
    if (start == null || startTime == null) return;

    final delta = event.localPosition - start;
    final duration = DateTime.now().difference(startTime);

    // 1. 边缘手势：返回 / 前进
    if (_edgeStartAtLeft &&
        delta.dx > widget.edgeThreshold &&
        delta.dx.abs() > delta.dy.abs() &&
        duration <= _edgeMaxDuration) {
      widget.onEdgeBack();
    } else if (_edgeStartAtRight &&
        delta.dx < -widget.edgeThreshold &&
        delta.dx.abs() > delta.dy.abs() &&
        duration <= _edgeMaxDuration) {
      widget.onEdgeForward();
    }

    // 2. 下拉刷新（仅上半屏 + 页面在顶部 + 下拉超过阈值）
    if (!_edgeStartAtLeft &&
        !_edgeStartAtRight &&
        _pullInUpperHalf &&
        _pullAtTop &&
        delta.dy > widget.pullThreshold &&
        delta.dy.abs() > delta.dx.abs() &&
        !_refreshing) {
      setState(() {
        _refreshing = true;
        _pullDistance = _pullMaxDistance;
      });
      await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _pullDistance = 0;
      });
    } else if (!_edgeStartAtLeft &&
        !_edgeStartAtRight &&
        _pullInUpperHalf &&
        _pullAtTop &&
        delta.dy > 30 &&
        delta.dy <= widget.pullThreshold &&
        delta.dy.abs() > delta.dx.abs()) {
      // 轻下拉（30-80pt）：聚焦地址栏
      widget.onPullToFocus?.call();
      setState(() {
        _pullDistance = 0;
      });
    } else {
      // 轻触页面（非边缘、非下拉）：通知外部让地址栏失焦
      if (!_edgeStartAtLeft &&
          !_edgeStartAtRight &&
          delta.distance < 10) {
        widget.onTapPage?.call();
      }
      setState(() {
        _pullDistance = 0;
      });
    }

    _downPosition = null;
    _downTime = null;
    _pullAtTop = false;
    _pullInUpperHalf = false;
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
              setState(() {
                _pullDistance = 0;
                _refreshing = false;
              });
              _downPosition = null;
              _downTime = null;
              _pullAtTop = false;
              _pullInUpperHalf = false;
            },
          ),
        ),
        // 下拉刷新指示器（仅上半屏下拉时显示）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: _pullDistance > 0 ? _pullDistance : 0,
              alignment: Alignment.bottomCenter,
              color: Colors.transparent,
              child: _pullDistance > 0
                  ? Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: _refreshing
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3B82F6),
                              ),
                            )
                          : const Icon(
                              Icons.arrow_downward,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
