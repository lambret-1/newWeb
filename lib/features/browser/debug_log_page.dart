import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/debug_logger.dart';

/// 全局调试日志页面：按模块过滤、查看、复制、分享。
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  LogModule? _filter; // null = 全部

  @override
  Widget build(BuildContext context) {
    final logger = DebugLogger.instance;
    final logs = logger.logsByModule(_filter);
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试日志'),
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
              Share.share(logger.allText, subject: '未来浏览器调试日志');
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
      body: Column(
        children: [
          // 模块过滤条
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _filterChip('全部', null),
                ...LogModule.values.map((m) => _filterChip(m.label, m)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final isError = entry.message.contains('❌') ||
                          entry.message.contains('失败') ||
                          entry.message.contains('error');
                      final isSuccess = entry.message.contains('✅');
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
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
                          '[${entry.time}][${entry.module.label}] ${entry.message}',
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
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, LogModule? module) {
    final selected = _filter == module;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filter = module;
          });
        },
      ),
    );
  }
}
