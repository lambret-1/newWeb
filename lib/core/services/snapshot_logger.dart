import 'package:flutter/foundation.dart';

/// 快照调试日志收集器：手机端可直接查看、复制、分享。
class SnapshotLogger {
  SnapshotLogger._();
  static final SnapshotLogger instance = SnapshotLogger._();

  final List<String> _logs = [];
  final int _maxLogs = 200;

  /// 写入一条日志（同时输出到 debugPrint）。
  void log(String message) {
    final time = DateTime.now().toString().substring(11, 23);
    final line = '[$time] $message';
    _logs.add(line);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    debugPrint('[NW-Snapshot] $message');
  }

  /// 获取全部日志（最新在最后）。
  List<String> get logs => List.unmodifiable(_logs);

  /// 全部日志拼接为字符串。
  String get allText => _logs.join('\n');

  /// 清空日志。
  void clear() => _logs.clear();
}
