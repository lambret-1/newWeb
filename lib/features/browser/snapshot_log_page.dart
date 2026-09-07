import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/snapshot_logger.dart';

/// 快照调试日志页面：查看、复制、分享日志。
class SnapshotLogPage extends StatefulWidget {
  const SnapshotLogPage({super.key});

  @override
  State<SnapshotLogPage> createState() => _SnapshotLogPageState();
}

class _SnapshotLogPageState extends State<SnapshotLogPage> {
  @override
  Widget build(BuildContext context) {
    final logger = SnapshotLogger.instance;
    final logs = logger.logs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('快照调试日志'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制全部',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: logger.allText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制到剪贴板'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () {
              Share.share(logger.allText, subject: '未来浏览器快照调试日志');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: () {
              logger.clear();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('日志已清空'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                '暂无日志\n请先打开网页并点击标签按钮触发截图',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final line = logs[index];
                final isError = line.contains('❌') || line.contains('失败');
                final isSuccess = line.contains('✅');
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFFEF2F2)
                        : isSuccess
                            ? const Color(0xFFF0FDF4)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isError
                          ? const Color(0xFFDC2626)
                          : isSuccess
                              ? const Color(0xFF16A34A)
                              : Colors.black87,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
