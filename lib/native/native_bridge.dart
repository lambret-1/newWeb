import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/services/debug_logger.dart';

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

  /// 用系统默认方式打开文件（如 .mobileconfig 会自动弹出设置应用安装）。
  static Future<bool> openSystemURL(String path) async {
    final result = await invoke('openSystemURL', {'path': path});
    return result == true;
  }

  /// 在 Safari 中打开网页 URL。
  static Future<bool> openWebURL(String url) async {
    final result = await invoke('openWebURL', {'url': url});
    return result == true;
  }

  /// 截取指定标签快照（Swift 直接 base64 返回 PNG，Dart 解码并写入 AppSupport）。
  /// Swift 端日志通过返回值的 logs 字段带回，写入 DebugLogger。
  static Future<Uint8List?> captureSnapshot(String url) async {
    final value = await invoke('captureSnapshot', {'url': url});
    if (value is! Map) {
      DebugLogger.instance.log('NativeBridge 返回值不是 Map: $value');
      return null;
    }
    // 提取 Swift 端日志
    final rawLogs = value['logs'];
    if (rawLogs is List) {
      for (final l in rawLogs) {
        if (l is String) DebugLogger.instance.log('[Swift] $l');
      }
    }
    final base64 = value['base64'] as String?;
    if (base64 == null || base64.isEmpty) {
      DebugLogger.instance.log('NativeBridge 返回 base64=null（截图失败）');
      return null;
    }
    try {
      final bytes = const Base64Decoder().convert(base64);
      DebugLogger.instance.log('Dart base64 解码成功, bytes=${bytes.length}');
      return bytes;
    } catch (e) {
      DebugLogger.instance.log('Dart base64 解码失败: $e');
      return null;
    }
  }

  /// 生成 AdGuard DNS 配置描述文件，返回文件路径。
  static Future<String?> generateDNSProfile() async {
    final value = await invoke('generateDNSProfile');
    return value is String ? value : null;
  }

  /// 长截图：滚动拼接整页网页，返回 base64 图片数据。
  static Future<String?> captureFullPage(String url) async {
    final value = await invoke('captureFullPage', {'url': url});
    if (value is! Map) return null;
    final rawLogs = value['logs'];
    if (rawLogs is List) {
      for (final l in rawLogs) {
        if (l is String) DebugLogger.instance.log('[Swift] $l');
      }
    }
    return value['base64'] as String?;
  }

  /// 保存 base64 图片到系统相册。
  static Future<Map<String, dynamic>?> saveImageToGallery(String base64) async {
    final value = await invoke('saveImageToGallery', {'base64': base64});
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// 分享图片（调用系统分享面板）。
  static Future<Map<String, dynamic>?> shareImage(String base64) async {
    final value = await invoke('shareImage', {'base64': base64});
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// 生成 WebClip 配置文件并弹出安装（添加到主屏幕）。
  static Future<Map<String, dynamic>?> generateWebClip(String url, String title) async {
    final value = await invoke('generateWebClip', {'url': url, 'title': title});
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }
}
