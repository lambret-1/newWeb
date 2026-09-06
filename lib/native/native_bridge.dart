import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生能力桥（MethodChannel）。
/// iOS 侧实现：NativeBridgePlugin（缓存管理；后续扩展离线保存 / 原生翻译）。
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.newweb/native');

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

  /// 清空全部网站数据（Cookie / 缓存 / localStorage 等）。
  static Future<void> clearWebData() async {
    await invoke('clearWebData');
  }

  /// 网站缓存大小（字节）。
  static Future<int> getCacheSize() async {
    final value = await invoke('getCacheSize');
    return value is int ? value : 0;
  }
}
