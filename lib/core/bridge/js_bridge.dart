import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_message.dart';

/// 桥接动作处理器：入参为 payload，返回可 JSON 序列化的结果。
typedef BridgeHandler = Future<dynamic> Function(Map<String, dynamic> payload);

/// JS Bridge：管理 Web→App（JavaScriptChannel）与 App→Web（runJavaScript）。
///
/// M1 内置 `ping` / `getAppInfo` 两个探活动作，用于验证通道连通；
/// `saveOffline` / `translate` / `share` / `download` 等动作在 M2+ 注册。
class JsBridge {
  static const String channelName = 'NativeBridge';

  /// 页面侧全局接收函数名（App→Web 回传目标）。
  static const String _responseTarget = r'window.__NEWWEB_NATIVE__';

  final Map<String, BridgeHandler> _handlers = {};

  JsBridge() {
    register('ping', (_) async => 'pong');
    register('getAppInfo', (_) async => {
          'name': 'NewWeb',
          'version': '0.1.0',
          'platform': 'ios',
        });
  }

  void register(String action, BridgeHandler handler) {
    _handlers[action] = handler;
  }

  /// 创建 Web→App 消息回调，挂载到 [WebViewController.addJavaScriptChannel]。
  ///
  /// webview_flutter 4.14 起无 JavaScriptChannel 类，改为
  /// `addJavaScriptChannel(name, onMessageReceived: ...)`。
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

  /// App→Web：页面加载前注入的桥接脚本，建立页面侧 `window.__NEWWEB_BRIDGE__`。
  static String injectScript() {
    return r'''
(function() {
  if (window.__NEWWEB_BRIDGE__) return;
  window.__NEWWEB_BRIDGE__ = {
    postMessage: function(msg) {
      try {
        if (window.NativeBridge && window.NativeBridge.postMessage) {
          window.NativeBridge.postMessage(JSON.stringify(msg));
        }
      } catch (e) { /* 静默 */ }
    },
    version: '0.1.0'
  };
})();
''';
  }

  /// App→Web：构造回传调用（页面需实现 `window.__NEWWEB_NATIVE__(msg)`）。
  static String buildResponseCall(BridgeResponse response) {
    final json = jsonEncode(response.toJson());
    return '$_responseTarget && $_responseTarget($json)';
  }
}
