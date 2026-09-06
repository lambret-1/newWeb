import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
/// 支持 LRU 保活：active=false 时销毁 WKWebView 释放内存，显示快照占位；
/// active=true 时重建 WebView 并恢复 URL + 滚动位置。
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
    this.active = true,
    this.snapshotBytes,
    this.snapshotPath,
    this.initialScrollY = 0,
    this.onScrollSaved,
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
  final void Function(String title, String url, String html)?
      onOfflineCollected;

  /// 整页翻译状态（state / total / done）。
  final void Function(String state, int total, int done)? onTranslateState;

  /// LRU 保活：false 时销毁 WebView 释放内存，显示快照占位。
  final bool active;

  /// 快照（内存字节），inactive 占位用。
  final Uint8List? snapshotBytes;

  /// 快照磁盘路径，inactive 占位用（内存为空时回退）。
  final String? snapshotPath;

  /// 重建 WebView 后恢复的滚动位置。
  final double initialScrollY;

  /// 离开标签前保存滚动位置回调。
  final ValueChanged<double>? onScrollSaved;

  @override
  State<WebViewPage> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  WebViewController? _controller;
  final JsBridge _bridge = JsBridge();
  bool _restoringScroll = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _createController();
    }
  }

  @override
  void didUpdateWidget(WebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      // 进入后台：保存滚动位置 → 销毁 WebView
      unawaited(_suspend());
    } else if (!oldWidget.active && widget.active) {
      // 回到前台：重建 WebView
      _createController();
    }
  }

  /// 创建 WebViewController 并加载页面。
  void _createController() {
    final controller = WebViewController();
    _controller = controller;

    _bridge.responseRunner = (script) {
      unawaited(
        controller.runJavaScript(script).catchError((Object e) {
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
            // 恢复滚动位置
            if (widget.initialScrollY > 1 && !_restoringScroll) {
              _restoringScroll = true;
              unawaited(
                controller
                    .runJavaScript(
                        'window.scrollTo(0, ${widget.initialScrollY});')
                    .catchError((_) {}),
              );
            }
            // 自动翻译白名单检测
            unawaited(_maybeAutoTranslate(url));
          },
          onUrlChange: (UrlChange change) {
            widget.onUrlChanged(change.url?.toString());
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                '[WebView] 资源错误 ${error.url}: ${error.description}');
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
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () {
        return AdBlockService.instance.ensureInjected();
      }),
    );
  }

  /// 挂起：保存滚动位置后销毁 WebView。
  Future<void> _suspend() async {
    await _saveScrollPosition();
    _controller = null;
    if (mounted) setState(() {});
  }

  /// 保存当前页面滚动位置。
  Future<void> _saveScrollPosition() async {
    final c = _controller;
    if (c == null) return;
    try {
      final pos = await c.getScrollPosition();
      widget.onScrollSaved?.call(pos.dy);
    } catch (_) {}
  }

  /// 注入功能脚本（弹窗兜底 / 整页翻译 / 阅读器 / 离线采集）。
  void _injectFeatureScripts() {
    final c = _controller;
    if (c == null) return;
    final scripts = [
      WebInjections.popupGuardScript(),
      WebInjections.pageTranslateScript(),
      WebInjections.readerExtractScript(),
      WebInjections.collectOfflineScript(),
    ];
    for (final script in scripts) {
      unawaited(
        c.runJavaScript(script).catchError((Object e) {
          debugPrint('[WebView] 脚本注入失败: $e');
        }),
      );
    }
  }

  Future<void> _refreshHistoryState() async {
    final c = _controller;
    if (c == null) return;
    final back = await c.canGoBack();
    final forward = await c.canGoForward();
    if (!mounted) return;
    widget.onCanGoBackChanged(back);
    widget.onCanGoForwardChanged(forward);
  }

  /// 查询页面是否在顶部（用于下拉刷新判定）。
  Future<bool> isAtTop() async {
    final c = _controller;
    if (c == null) return true;
    try {
      final offset = await c.getScrollPosition();
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
      final should =
          await SettingsService.instance.shouldAutoTranslate(uri.host);
      if (!should) return;
      await translatePage();
    } catch (_) {}
  }

  // ---- 供 BrowserScreen 调用的导航操作 ----

  Future<void> load(String input) async {
    final c = _controller;
    if (c == null) return;
    final engine = await SettingsService.instance.getSearchEngine();
    final uri = AppConfig.normalizeInput(
      input,
      searchUrl: SettingsService.searchUrlOf(engine),
    );
    await c.loadRequest(uri);
  }

  Future<void> goBack() async {
    final c = _controller;
    if (c == null) return;
    if (await c.canGoBack()) await c.goBack();
  }

  Future<void> goForward() async {
    final c = _controller;
    if (c == null) return;
    if (await c.canGoForward()) await c.goForward();
  }

  Future<void> reload() async {
    final c = _controller;
    if (c == null) return;
    await c.reload();
  }

  Future<void> goHome() async {
    final c = _controller;
    if (c == null) return;
    await c.loadRequest(Uri.parse(AppConfig.homeUrl));
  }

  /// 保存离线页面：触发页面采集（完成后经 JS Bridge 回传）。
  Future<void> saveOffline() async {
    final c = _controller;
    if (c == null) return;
    await c.runJavaScript(WebInjections.collectOfflineScript());
    await c.runJavaScript(
      'window.__NEWWEB_COLLECT__ && window.__NEWWEB_COLLECT__();',
    );
  }

  /// 加载本地 HTML 文件（离线页面）。
  Future<void> loadFile(String path) async {
    final c = _controller;
    if (c == null) return;
    await c.loadFile(path);
  }

  // ---- 网页翻译 ----

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
    final c = _controller;
    if (c == null) return 'noop';
    await c.runJavaScript(WebInjections.pageTranslateScript());
    final mode = await SettingsService.instance.getTranslateMode();
    final result = await c.runJavaScriptReturningResult(
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
    final c = _controller;
    if (c == null) return false;
    try {
      final state = await c.runJavaScriptReturningResult(
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
    final c = _controller;
    if (c == null) return null;
    try {
      await c.runJavaScript(WebInjections.readerExtractScript());
      final result = (await c.runJavaScriptReturningResult(
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
    final c = _controller;
    if (c != null) {
      return WebViewWidget(controller: c);
    }
    // inactive 占位：优先内存快照，其次磁盘快照，最后空白占位
    if (widget.snapshotBytes != null) {
      return Image.memory(
        widget.snapshotBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (widget.snapshotPath != null &&
        File(widget.snapshotPath!).existsSync()) {
      return Image.file(
        File(widget.snapshotPath!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return Container(
      color: const Color(0xFFF5F6F8),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pages_outlined, size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 8),
            Text(
              '标签已休眠',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
