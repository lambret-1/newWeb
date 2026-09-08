import 'package:flutter/foundation.dart';

/// 日志模块分类。
enum LogModule {
  general('通用'),
  snapshot('快照'),
  download('下载'),
  adblock('广告拦截'),
  translate('翻译'),
  navigation('导航'),
  native('原生'),
  update('更新');

  final String label;
  const LogModule(this.label);
}

/// 全局调试日志收集器：按模块分类，手机端可查看/复制/分享。
class DebugLogger {
  DebugLogger._();
  static final DebugLogger instance = DebugLogger._();

  final List<DebugLogEntry> _logs = [];
  final int _maxLogs = 500;

  /// 写入一条日志。
  void log(String message, {LogModule module = LogModule.general}) {
    final time = DateTime.now().toString().substring(11, 23);
    _logs.add(DebugLogEntry(time: time, message: message, module: module));
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    debugPrint('[NW-${module.name}] $message');
  }

  /// 获取全部日志。
  List<DebugLogEntry> get logs => List.unmodifiable(_logs);

  /// 按模块过滤。
  List<DebugLogEntry> logsByModule(LogModule? module) {
    if (module == null) return List.unmodifiable(_logs);
    return _logs.where((l) => l.module == module).toList(growable: false);
  }

  /// 全部日志拼接为字符串。
  String get allText => _logs.map((l) => '[${l.time}][${l.module.label}] ${l.message}').join('\n');

  /// 清空日志。
  void clear() => _logs.clear();
}

/// 单条日志。
class DebugLogEntry {
  final String time;
  final String message;
  final LogModule module;

  const DebugLogEntry({
    required this.time,
    required this.message,
    required this.module,
  });
}
