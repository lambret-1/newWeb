import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/bridge/js_bridge.dart';
import '../../core/config/app_config.dart';

/// WebView 容器页：封装加载、进度、历史状态、JS Bridge 注入。
/// 每个标签页一个实例（内部持有独立 WebViewController，随 widget 保活）。
class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.onProgress,
    required this.onUrlChanged,
    required this.onCanGoBackChanged,
    required this.onCanGoForwardChanged,
    this.initialUrl = AppConfig.homeUrl,
    this.onPageStarted,
    this.onPageFinished,
    this.onTitleChanged,
  });

  final ValueChanged<double> onProgress;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<bool> onCanGoBackChanged;
  final ValueChanged<bool> onCanGoForwardChanged;
  final String initialUrl;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<String>? onPageFinished;
  final ValueChanged<String>? onTitleChanged;

  @override
  State<WebViewPage> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  final JsBridge _bridge = JsBridge();

  @override
  void initState() {
    super.initState();

    final controller = WebViewController();
    _controller = controller;

    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      controller.setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1 ${AppConfig.userAgentSuffix}',
      ),
    );
    unawaited(controller.setBackgroundColor(const Color(0xFFF5F6F8)));
    unawaited(
      controller.addJavaScriptChannel(
        JsBridge.channelName,
        onMessageReceived: _bridge.messageHandler(),
      ),
    );
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            widget.onProgress(progress / 100);
          },
          onPageStarted: (String url) {
            _injectBridge();
            _refreshHistoryState();
            widget.onPageStarted?.call(url);
          },
          onPageFinished: (String url) async {
            _injectBridge();
            _refreshHistoryState();
            widget.onPageFinished?.call(url);
            final title = await controller.getTitle();
            if (title != null && title.isNotEmpty) {
              widget.onTitleChanged?.call(title);
            }
          },
          onUrlChange: (UrlChange change) {
            widget.onUrlChanged(change.url?.toString());
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebView] 资源错误 ${error.url}: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      ),
    );
    unawaited(controller.loadRequest(Uri.parse(widget.initialUrl)));
  }

  void _injectBridge() {
    unawaited(
      _controller.runJavaScript(JsBridge.injectScript()).catchError(
        (Object e) => debugPrint('[WebView] 桥接注入失败: $e'),
      ),
    );
  }

  Future<void> _refreshHistoryState() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) return;
    widget.onCanGoBackChanged(back);
    widget.onCanGoForwardChanged(forward);
  }

  /// 查询页面是否在顶部（用于下拉刷新判定）。
  Future<bool> isAtTop() async {
    try {
      final offset = await _controller.getScrollPosition();
      return offset.dy <= 1;
    } catch (_) {
      return true;
    }
  }

  // ---- 供 BrowserScreen 调用的导航操作 ----

  Future<void> load(String input) async {
    await _controller.loadRequest(AppConfig.normalizeInput(input));
  }

  Future<void> goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
    }
  }

  Future<void> reload() async {
    await _controller.reload();
  }

  Future<void> goHome() async {
    await _controller.loadRequest(Uri.parse(AppConfig.homeUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
