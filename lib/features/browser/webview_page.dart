import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/bridge/js_bridge.dart';
import '../../core/bridge/web_injections.dart';
import '../../core/config/app_config.dart';
import '../../core/services/adblock_service.dart';
import '../../core/services/download_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/translate_service.dart';

/// WebView 容器页：封装加载、进度、历史状态、JS Bridge 与功能脚本注入。
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
    this.onOfflineCollected,
    this.onTranslateState,
  });

  final ValueChanged<double> onProgress;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<bool> onCanGoBackChanged;
  final ValueChanged<bool> onCanGoForwardChanged;
  final String initialUrl;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<String>? onPageFinished;
  final ValueChanged<String>? onTitleChanged;

  /// 离线页面采集完成（title, url, html）。
  final void Function(String title, String url, String html)? onOfflineCollected;

  /// 整页翻译状态（state / total / done）。
  final void Function(String state, int total, int done)? onTranslateState;

  @override
  State<WebViewPage> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  final JsBridge _bridge = JsBridge();

  @override
  void initState() {
    super.initState();

    // 桥接响应执行器与业务注入
    _bridge.responseRunner = (script) {
      unawaited(
        _controller.runJavaScript(script).catchError((Object e) {
          debugPrint('[JsBridge] 回传失败: $e');
        }),
      );
    };
    _bridge.translateHandler = (String text, {String mode = 'auto'}) {
      return TranslateService.instance.translate(text, mode: mode);
    };
    _bridge.onOfflineCollected = (title, url, html) {
      widget.onOfflineCollected?.call(title, url, html);
    };
    _bridge.onTranslateState = (state, total, done) {
      widget.onTranslateState?.call(state, total, done);
    };

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
            _injectFeatureScripts();
            _refreshHistoryState();
            widget.onPageStarted?.call(url);
          },
          onPageFinished: (String url) async {
            _injectFeatureScripts();
            _refreshHistoryState();
            widget.onPageFinished?.call(url);
            final title = await controller.getTitle();
            if (title != null && title.isNotEmpty) {
              widget.onTitleChanged?.call(title);
            }
            // 自动翻译白名单检测
            unawaited(_maybeAutoTranslate(url));
          },
          onUrlChange: (UrlChange change) {
            widget.onUrlChanged(change.url?.toString());
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebView] 资源错误 ${error.url}: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (request.isMainFrame && _isDownloadUrl(url)) {
              debugPrint('[WebView] 检测到下载链接: $url');
              _confirmStartDownload(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      ),
    );
    unawaited(controller.loadRequest(Uri.parse(widget.initialUrl)));
    // WebView 挂载后幂等补注入内容拦截器
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () {
        return AdBlockService.instance.ensureInjected();
      }),
    );
  }

  /// 注入功能脚本（弹窗兜底 / 整页翻译 / 阅读器 / 离线采集）。
  void _injectFeatureScripts() {
    final scripts = [
      WebInjections.popupGuardScript(),
      WebInjections.pageTranslateScript(),
      WebInjections.readerExtractScript(),
      WebInjections.collectOfflineScript(),
    ];
    for (final script in scripts) {
      unawaited(
        _controller.runJavaScript(script).catchError((Object e) {
          debugPrint('[WebView] 脚本注入失败: $e');
        }),
      );
    }
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

  /// 自动翻译：命中白名单域名且页面未翻译时触发整页翻译。
  Future<void> _maybeAutoTranslate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return;
      final should = await SettingsService.instance.shouldAutoTranslate(uri.host);
      if (!should) return;
      await translatePage();
    } catch (_) {
      // 忽略解析失败
    }
  }

  // ---- 供 BrowserScreen 调用的导航操作 ----

  Future<void> load(String input) async {
    final engine = await SettingsService.instance.getSearchEngine();
    final uri = AppConfig.normalizeInput(
      input,
      searchUrl: SettingsService.searchUrlOf(engine),
    );
    await _controller.loadRequest(uri);
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

  /// 保存离线页面：触发页面采集（完成后经 JS Bridge 回传）。
  Future<void> saveOffline() async {
    await _controller.runJavaScript(WebInjections.collectOfflineScript());
    await _controller.runJavaScript(
      'window.__NEWWEB_COLLECT__ && window.__NEWWEB_COLLECT__();',
    );
  }

  /// 加载本地 HTML 文件（离线页面）。
  Future<void> loadFile(String path) async {
    await _controller.loadFile(path);
  }

  // ---- 网页翻译 ----

  /// 常见下载文件后缀（大小写不敏感）。
  static const Set<String> _downloadExtensions = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz',
    'apk', 'ipa', 'dmg', 'exe', 'msi', 'deb', 'pkg',
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'torrent', 'iso', 'dll', 'so',
  };

  bool _isDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return _downloadExtensions.any(path.endsWith);
  }

  /// 下载前弹窗确认，确认后开始原生下载。
  Future<void> _confirmStartDownload(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开始下载？'),
        content: Text(
          url,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('下载'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      DownloadService.instance.start(url);
    }
  }

  /// 手动翻译当前页；若已翻译则恢复原文。返回操作类型。
  Future<String> translatePage() async {
    await _controller.runJavaScript(WebInjections.pageTranslateScript());
    final mode = await SettingsService.instance.getTranslateMode();
    final result = await _controller.runJavaScriptReturningResult(
      '''(function(){
        var pt = window.__NEWWEB_PAGE_TRANSLATE__;
        if (!pt) return 'noop';
        var s = pt.getState();
        if (s === 'translated' || s === 'translating') {
          pt.restore();
          return 'restored';
        }
        pt.translate(300, 10, '$mode');
        return 'started';
      })();''',
    );
    return result is String ? result : 'noop';
  }

  /// 页面是否处于翻译状态。
  Future<bool> isPageTranslated() async {
    try {
      final state = await _controller.runJavaScriptReturningResult(
        '''(function(){
          var pt = window.__NEWWEB_PAGE_TRANSLATE__;
          return pt ? pt.getState() : 'idle';
        })();''',
      );
      return state == 'translated' || state == 'translating';
    } catch (_) {
      return false;
    }
  }

  // ---- 阅读器模式 ----

  /// 提取正文，返回 {title, html, url}；提取失败返回 null。
  Future<Map<String, String>?> extractReader() async {
    try {
      await _controller.runJavaScript(WebInjections.readerExtractScript());
      final result = (await _controller.runJavaScriptReturningResult(
        'JSON.stringify((window.__NEWWEB_READER__ && window.__NEWWEB_READER__()) || null)',
      )) as String?;
      if (result == null || result == 'null') return null;
      final data = jsonDecode(result) as Map<String, dynamic>;
      return {
        'title': (data['title'] ?? '阅读模式') as String,
        'html': (data['html'] ?? '') as String,
        'url': (data['url'] ?? '') as String,
      };
    } catch (e) {
      debugPrint('[Reader] 提取失败: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
