import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_message.dart';

/// 桥接动作处理器：入参为 payload，返回可 JSON 序列化的结果。
typedef BridgeHandler = Future<dynamic> Function(Map<String, dynamic> payload);

/// JS Bridge：管理 Web→App（JavaScriptChannel）与 App→Web（runJavaScript）。
///
/// 内置动作：
/// - `ping` / `getAppInfo`：通道探活
/// - `translate`：选中文本翻译（结果经 runJavaScript 回传页面浮动卡片）
/// - `offlineCollected`：离线页面采集完成（回传归档 HTML）
class JsBridge {
  static const String channelName = 'NativeBridge';

  final Map<String, BridgeHandler> _handlers = {};

  /// App→Web 脚本执行器（由 WebViewPage 注入，执行 runJavaScript）。
  void Function(String script)? responseRunner;

  /// 翻译实现（由外部注入 TranslateService）。
  Future<String?> Function(String text)? translateHandler;

  /// 离线采集完成回调（title, url, html）。
  void Function(String title, String url, String html)? onOfflineCollected;

  JsBridge() {
    register('ping', (_) async => 'pong');
    register('getAppInfo', (_) async => {
          'name': '未来浏览器',
          'version': '1.0.2',
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

    // 特判：选中文本翻译（需要回传页面）
    if (msg.action == 'translate') {
      await _handleTranslate(msg);
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

  Future<void> _handleTranslate(BridgeMessage msg) async {
    final text = (msg.payload['text'] ?? '') as String;
    String? result;
    try {
      result = await translateHandler?.call(text);
    } catch (e) {
      debugPrint('[JsBridge] 翻译失败: $e');
    }
    final ok = result != null;
    final script =
        'window.__NEWWEB_TRANSLATE_RESULT__(${_jsString(msg.id)}, '
        '$ok, ${_jsString(result ?? '翻译服务暂不可用')});';
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
