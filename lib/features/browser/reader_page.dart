import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 阅读器模式：以原生 WebView 渲染提取的正文，支持字号调节。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.title,
    required this.html,
    required this.sourceUrl,
  });

  final String title;
  final String html;
  final String sourceUrl;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final WebViewController _controller;
  double _fontSize = 18;

  String _buildHtml() {
    final safeTitle =
        widget.title.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0">
<style>
  body {
    font-family: -apple-system, "PingFang SC", sans-serif;
    font-size: ${_fontSize}px;
    line-height: 1.8;
    color: #1F2937;
    padding: 16px;
    max-width: 720px;
    margin: 0 auto;
    background: #FFFFFF;
  }
  h1 { font-size: ${_fontSize + 6}px; font-weight: 700; margin: 8px 0 16px; }
  h2, h3 { line-height: 1.5; }
  p { margin: 12px 0; }
  img { max-width: 100%; height: auto; border-radius: 8px; }
  a { color: #3B82F6; word-break: break-all; }
  pre, code { white-space: pre-wrap; word-break: break-all; font-size: ${_fontSize - 2}px; }
  blockquote { border-left: 3px solid #E5E7EB; margin: 12px 0; padding-left: 12px; color: #6B7280; }
  table { width: 100%; border-collapse: collapse; }
  td, th { border: 1px solid #E5E7EB; padding: 6px 8px; }
</style>
</head>
<body>
<h1>$safeTitle</h1>
${widget.html}
<div style="height: 60px;"></div>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
    _controller.loadHtmlString(_buildHtml(), baseUrl: widget.sourceUrl);
  }

  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(14.0, 28.0);
    });
    _controller.loadHtmlString(_buildHtml(), baseUrl: widget.sourceUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            color: const Color(0xFF374151),
            onPressed: () => _changeFontSize(-2),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            color: const Color(0xFF374151),
            onPressed: () => _changeFontSize(2),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
