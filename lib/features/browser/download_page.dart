import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/download_service.dart';
import '../../native/native_bridge.dart';

/// 下载管理器：进行中任务（进度/暂停/续传/取消）+ 已完成文件（打开/分享/删除）。
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  List<DownloadedFile> _files = [];

  @override
  void initState() {
    super.initState();
    DownloadService.instance.ensureListening();
    DownloadService.instance.version.addListener(_onChanged);
    _loadFiles();
  }

  @override
  void dispose() {
    DownloadService.instance.version.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await DownloadService.instance.listCompletedFiles();
    if (!mounted) return;
    setState(() => _files = files);
  }

  String _fileName(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (seg.isNotEmpty) return seg.last;
    } catch (_) {}
    return '下载文件';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = DownloadService.instance.activeTasks;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '下载管理',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          children: [
            if (tasks.isNotEmpty) ...[
              _sectionTitle('进行中（${tasks.length}）'),
              ...tasks.map(_buildTaskTile),
            ],
            _sectionTitle('已下载（${_files.length}）'),
            if (_files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '暂无下载文件',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ),
              )
            else
              ..._files.map(_buildFileTile),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildTaskTile(DownloadTaskInfo task) {
    final name = task.fileName ?? _fileName(task.url);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              _statusText(task),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.status == DownloadStatus.error ? 0 : task.progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFEDEFF3),
              color: task.status == DownloadStatus.error
                  ? const Color(0xFFEA6668)
                  : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.status == DownloadStatus.error
                      ? (task.message ?? '下载失败')
                      : '${DownloadService.formatSize(task.received)}'
                          '${task.total > 0 ? ' / ${DownloadService.formatSize(task.total)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ),
              _taskActions(task),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusText(DownloadTaskInfo task) {
    String text;
    Color color;
    switch (task.status) {
      case DownloadStatus.downloading:
        text = '下载中';
        color = const Color(0xFF3B82F6);
      case DownloadStatus.paused:
        text = '已暂停';
        color = const Color(0xFFFAAD14);
      case DownloadStatus.completed:
        text = '已完成';
        color = const Color(0xFF52C41A);
      case DownloadStatus.error:
        text = '失败';
        color = const Color(0xFFEA6668);
    }
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    );
  }

  Widget _taskActions(DownloadTaskInfo task) {
    final actions = <Widget>[];
    if (task.status == DownloadStatus.downloading) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.pause, size: 18, color: Color(0xFF6B7280)),
          visualDensity: VisualDensity.compact,
          onPressed: () => DownloadService.instance.pause(task.taskId),
        ),
      );
    } else if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.error) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.play_arrow, size: 18, color: Color(0xFF3B82F6)),
          visualDensity: VisualDensity.compact,
          onPressed: () => DownloadService.instance.resume(task.taskId),
        ),
      );
    }
    actions.add(
      IconButton(
        icon: const Icon(Icons.close, size: 18, color: Color(0xFFB0B7C3)),
        visualDensity: VisualDensity.compact,
        onPressed: () => DownloadService.instance.cancel(task.taskId),
      ),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  Widget _buildFileTile(DownloadedFile file) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.insert_drive_file_outlined,
              size: 18, color: Color(0xFF3B82F6)),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          DownloadService.formatSize(file.size),
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        onTap: () => NativeBridge.previewFile(file.path),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFB0B7C3)),
          onSelected: (value) async {
            switch (value) {
              case 'open':
                await NativeBridge.previewFile(file.path);
              case 'share':
                await Share.shareXFiles([XFile(file.path)]);
              case 'delete':
                await DownloadService.instance.deleteFile(file.path);
                _loadFiles();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('打开')),
            PopupMenuItem(value: 'share', child: Text('分享')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }
}
