import 'package:flutter/material.dart';

/// 页面加载进度条（progress 取值 0~1，加载完成时隐藏）。
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) {
      return const SizedBox(height: 2);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 2,
        backgroundColor: Colors.transparent,
        color: const Color(0xFF3B82F6),
      ),
    );
  }
}
