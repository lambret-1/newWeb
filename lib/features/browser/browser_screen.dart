import 'package:flutter/material.dart';

import 'webview_page.dart';
import 'widgets/address_bar.dart';
import 'widgets/progress_bar.dart';
import 'widgets/tool_bar.dart';

/// 浏览器主界面：地址栏 + WebView + 工具栏。
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _addressController = TextEditingController();
  final GlobalKey<WebViewPageState> _webViewKey = GlobalKey<WebViewPageState>();

  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _addressController.text = '正在加载首页…';
  }

  void _onProgress(double progress) {
    setState(() => _progress = progress);
  }

  void _onUrlChanged(String? url) {
    if (url != null && !_addressController.text.contains(url)) {
      _addressController.text = url;
    }
  }

  void _onCanGoBackChanged(bool value) => setState(() => _canGoBack = value);

  void _onCanGoForwardChanged(bool value) => setState(() => _canGoForward = value);

  void _submit(String input) {
    FocusScope.of(context).unfocus();
    _webViewKey.currentState?.load(input);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature 将在 M2 里程碑提供'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                AddressBar(
                  controller: _addressController,
                  onSubmit: _submit,
                  onReload: () => _webViewKey.currentState?.reload(),
                ),
                ProgressBar(progress: _progress),
              ],
            ),
          ),
          Expanded(
            child: WebViewPage(
              key: _webViewKey,
              onProgress: _onProgress,
              onUrlChanged: _onUrlChanged,
              onCanGoBackChanged: _onCanGoBackChanged,
              onCanGoForwardChanged: _onCanGoForwardChanged,
            ),
          ),
          ToolBar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _webViewKey.currentState?.goBack(),
            onForward: () => _webViewKey.currentState?.goForward(),
            onHome: () => _webViewKey.currentState?.goHome(),
            onComingSoon: () => _showComingSoon('标签页/更多'),
          ),
        ],
      ),
    );
  }
}
