import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 网页源码查看器：获取当前网页 HTML 源码，深色代码风格展示。
class SourceCodePage extends StatefulWidget {
  final String url;
  final String? title;

  const SourceCodePage({super.key, required this.url, this.title});

  @override
  State<SourceCodePage> createState() => _SourceCodePageState();
}

class _SourceCodePageState extends State<SourceCodePage> {
  String _source = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  Future<void> _loadSource() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(widget.url),
        headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        setState(() {
          _source = response.body;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '请求失败：HTTP ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _source));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制全部源码'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: Text(
          widget.title ?? '网页源码',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _loading ? null : _copyAll,
            child: const Text('复制全部', style: TextStyle(fontSize: 14, color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(color: Colors.white54))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.white30),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        color: const Color(0xFF4FC3F7),
                        onPressed: _loadSource,
                        child: const Text('重试', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSource,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _source,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFFD4D4D4),
                      ),
                    ),
                  ),
                ),
    );
  }
}
