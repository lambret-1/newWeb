import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生能力桥（MethodChannel + EventChannel）。
/// iOS 侧实现：NativeBridgePlugin（缓存 / 内容拦截器 / 下载 / 预览 / DNS）。
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.newweb/native');
  static const EventChannel _events = EventChannel('com.newweb/native_events');

  /// 原生事件流（下载进度、长按菜单动作）。
  static Stream<Map<String, dynamic>> events() {
    return _events
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map));
  }

  static Future<dynamic> invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      return await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      debugPrint('[NativeBridge] $method 未实现');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] $method 失败: ${e.message}');
      return null;
    }
  }

  // ---- 缓存管理 ----

  /// 清空全部网站数据（Cookie / 缓存 / localStorage 等）。
  static Future<void> clearWebData() async {
    await invoke('clearWebData');
  }

  /// 按类型清空网站数据：cookies / diskCache / localStorage / indexedDB / websql。
  static Future<void> clearWebDataTypes(List<String> types) async {
    await invoke('clearWebDataTypes', {'types': types});
  }

  /// 网站缓存大小（字节）：沙盒 Caches 目录。
  static Future<int> getCacheSize() async {
    final value = await invoke('getCacheSize');
    return value is int ? value : 0;
  }

  /// 清理 HTTP 缓存（URLCache + 沙盒 Caches 目录）。
  static Future<void> clearHttpCache() async {
    await invoke('clearHttpCache');
  }

  /// 网站数据记录条数（Cookie / 缓存 / 存储 各类记录总数）。
  static Future<int> getWebDataRecordCount() async {
    final value = await invoke('getWebDataRecordCount');
    return value is int ? value : 0;
  }

  // ---- 内容拦截器 ----

  /// 注入 WKContentRuleList 规则（JSON 字符串），并注入所有 WebView。
  static Future<bool> injectContentBlocker(String rulesJson) async {
    final value = await invoke('injectContentBlocker', {'rules': rulesJson});
    return value == true;
  }

  // ---- 下载管理 ----

  static Future<void> startDownload(String url, String taskId) async {
    await invoke('startDownload', {'url': url, 'taskId': taskId});
  }

  static Future<void> pauseDownload(String taskId) async {
    await invoke('pauseDownload', {'taskId': taskId});
  }

  static Future<void> resumeDownload(String taskId, String url) async {
    await invoke('resumeDownload', {'taskId': taskId, 'url': url});
  }

  static Future<void> cancelDownload(String taskId) async {
    await invoke('cancelDownload', {'taskId': taskId});
  }

  // ---- 文件预览 / DNS ----

  static Future<void> previewFile(String path) async {
    await invoke('previewFile', {'path': path});
  }

  /// 生成 AdGuard DNS 配置描述文件，返回文件路径。
  static Future<String?> generateDNSProfile() async {
    final value = await invoke('generateDNSProfile');
    return value is String ? value : null;
  }
}
