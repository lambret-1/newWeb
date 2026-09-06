import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_message.dart';

/// 桥接动作处理器：入参为 payload，返回可 JSON 序列化的结果。
typedef BridgeHandler = Future<dynamic> Function(Map<String, dynamic> payload);

/// JS Bridge：管理 Web→App（JavaScriptChannel）与 App→Web（runJavaScript）。
///
/// 内置动作：
/// - `ping` / `getAppInfo`：通道探活
/// - `translateBatch`：整页翻译批次（结果经 runJavaScript 回传页面替换）
/// - `translateState`：整页翻译状态（通知 Dart 展示进度）
/// - `offlineCollected`：离线页面采集完成（回传归档 HTML）
class JsBridge {
  static const String channelName = 'NativeBridge';

  final Map<String, BridgeHandler> _handlers = {};

  /// App→Web 脚本执行器（由 WebViewPage 注入，执行 runJavaScript）。
  void Function(String script)? responseRunner;

  /// 翻译实现（由外部注入 TranslateService）。
  Future<String?> Function(String text, {String mode})? translateHandler;

  /// 翻译模式获取器（由外部注入，读取设置）。
  String Function()? translateModeGetter;

  /// 离线采集完成回调（title, url, html）。
  void Function(String title, String url, String html)? onOfflineCollected;

  /// 整页翻译状态回调（state / total / done）。
  void Function(String state, int total, int done)? onTranslateState;

  JsBridge() {
    register('ping', (_) async => 'pong');
    register('getAppInfo', (_) async => {
          'name': '未来浏览器',
          'version': '1.0.4',
          'platform': 'ios',
        });
  }

  void register(String action, BridgeHandler handler) {
    _handlers[action] = handler;
  }

  /// 创建 Web→App 消息回调，挂载到 [WebViewController.addJavaScriptChannel]。
  void Function(JavaScriptMessage) messageHandler() {
    return (JavaScriptMessage message) async {
      await _dispatch(message.message);
    };
  }

  Future<void> _dispatch(String raw) async {
    BridgeMessage msg;
    try {
      msg = BridgeMessage.fromJson(raw);
    } catch (e) {
      debugPrint('[JsBridge] 非法消息: $e');
      return;
    }

    // 特判：整页翻译批次（翻译结果回传页面）
    if (msg.action == 'translateBatch') {
      await _handleTranslateBatch(msg);
      return;
    }

    // 特判：整页翻译状态
    if (msg.action == 'translateState') {
      onTranslateState?.call(
        (msg.payload['state'] ?? '') as String,
        (msg.payload['total'] ?? 0) as int,
        (msg.payload['done'] ?? 0) as int,
      );
      return;
    }

    // 特判：离线采集完成
    if (msg.action == 'offlineCollected') {
      final payload = msg.payload;
      onOfflineCollected?.call(
        (payload['title'] ?? '离线页面') as String,
        (payload['url'] ?? '') as String,
        (payload['html'] ?? '') as String,
      );
      return;
    }

    final handler = _handlers[msg.action];
    if (handler == null) {
      debugPrint('[JsBridge] 未注册动作: ${msg.action}');
      return;
    }

    try {
      await handler(msg.payload);
    } catch (e) {
      debugPrint('[JsBridge] 动作 ${msg.action} 执行失败: $e');
    }
  }

  /// 整页翻译批次处理：逐条翻译后回传页面替换文本。
  Future<void> _handleTranslateBatch(BridgeMessage msg) async {
    final payload = msg.payload;
    final texts = (payload['texts'] as List?)?.cast<String>() ?? [];
    final indices = (payload['indices'] as List?)?.cast<int>() ?? [];
    final mode = (payload['mode'] as String?) ?? 'auto';

    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < texts.length; i++) {
      String? result;
      try {
        result = await translateHandler?.call(texts[i], mode: mode);
      } catch (e) {
        debugPrint('[JsBridge] 批次翻译失败: $e');
      }
      if (result != null) {
        results.add({'index': indices[i], 'text': result});
      }
    }

    final script =
        'window.__NEWWEB_PAGE_TRANSLATE_APPLY__(${_jsString(msg.id)}, '
        '${jsonEncode(results)});';
    responseRunner?.call(script);
  }

  /// 将字符串转为 JS 安全字面量。
  static String _jsString(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', '');
    return "'$escaped'";
  }
}
