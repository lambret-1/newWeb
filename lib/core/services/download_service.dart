import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../native/native_bridge.dart';

/// 下载任务状态。
enum DownloadStatus { downloading, paused, completed, error }

/// 下载任务信息。
class DownloadTaskInfo {
  DownloadTaskInfo({
    required this.taskId,
    required this.url,
    required this.status,
    this.fileName,
    this.received = 0,
    this.total = -1,
    this.message,
  });

  final String taskId;
  final String url;
  DownloadStatus status;
  String? fileName;
  int received;
  int total;
  String? message;

  double get progress {
    if (total <= 0) return 0;
    return (received / total).clamp(0.0, 1.0);
  }
}

/// 已下载文件条目。
class DownloadedFile {
  const DownloadedFile({required this.path, required this.name, required this.size});

  final String path;
  final String name;
  final int size;
}

/// 下载服务：转发原生下载事件，维护任务状态（进程内存）。
class DownloadService {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  final Map<String, DownloadTaskInfo> _tasks = {};
  final ValueNotifier<int> _version = ValueNotifier(0);
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _listening = false;

  /// 任务变更通知（页面监听刷新）。
  ValueNotifier<int> get version => _version;

  /// 订阅原生事件（幂等）。
  void ensureListening() {
    if (_listening) return;
    _listening = true;
    _sub = NativeBridge.events().listen(_onEvent, onError: (e) {
      debugPrint('[Download] 事件监听失败: $e');
    });
  }

  /// 释放事件订阅。
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
  }

  void _onEvent(Map<String, dynamic> e) {
    final event = e['event'] as String?;
    if (event == null || !event.startsWith('download_')) return;
    final taskId = e['taskId'] as String?;
    if (taskId == null) return;

    switch (event) {
      case 'download_started':
        _tasks[taskId] ??= DownloadTaskInfo(
          taskId: taskId,
          url: e['url'] as String? ?? '',
          status: DownloadStatus.downloading,
        );
      case 'download_progress':
        final task = _tasks[taskId];
        if (task != null) {
          task.received = (e['received'] as int?) ?? 0;
          task.total = (e['total'] as int?) ?? -1;
        }
      case 'download_completed':
        final task = _tasks[taskId];
        if (task != null) {
          task.status = DownloadStatus.completed;
          task.fileName = e['name'] as String? ?? task.fileName;
          task.received = task.total;
        }
      case 'download_paused':
        _tasks[taskId]?.status = DownloadStatus.paused;
      case 'download_resumed':
        _tasks[taskId]?.status = DownloadStatus.downloading;
      case 'download_cancelled':
        _tasks.remove(taskId);
      case 'download_error':
        final task = _tasks[taskId];
        if (task != null) {
          task.status = DownloadStatus.error;
          task.message = e['message'] as String?;
        }
    }
    _version.value++;
  }

  /// 开始下载，返回 taskId。
  String start(String url) {
    ensureListening();
    final taskId = 't${DateTime.now().millisecondsSinceEpoch}';
    _tasks[taskId] = DownloadTaskInfo(
      taskId: taskId,
      url: url,
      status: DownloadStatus.downloading,
    );
    NativeBridge.startDownload(url, taskId);
    _version.value++;
    return taskId;
  }

  Future<void> pause(String taskId) async {
    await NativeBridge.pauseDownload(taskId);
  }

  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    await NativeBridge.resumeDownload(taskId, task.url);
  }

  Future<void> cancel(String taskId) async {
    await NativeBridge.cancelDownload(taskId);
  }

  List<DownloadTaskInfo> get activeTasks =>
      _tasks.values.where((t) => t.status != DownloadStatus.completed).toList();

  /// 已完成文件列表（扫描 Downloads 目录）。
  Future<List<DownloadedFile>> listCompletedFiles() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Downloads'));
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>();
    final result = <DownloadedFile>[];
    for (final f in files) {
      final stat = await f.stat();
      result.add(DownloadedFile(
        path: f.path,
        name: p.basename(f.path),
        size: stat.size,
      ));
    }
    result.sort((a, b) => b.size.compareTo(a.size));
    return result;
  }

  /// 删除已下载文件。
  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// 格式化大小。
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
