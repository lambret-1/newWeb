import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生能力桥（MethodChannel），M2+ 逐步接入：
/// - saveOffline（离线完整保存）
/// - translate（翻译）
/// - share / download（系统分享、下载）
/// - vpn（网络代理）
///
/// M1 阶段仅做通道约定：iOS 侧未实现时，调用会返回 null 而非崩溃。
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
      debugPrint('[NativeBridge] $method 未实现（M1 占位）');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] $method 失败: ${e.message}');
      return null;
    }
  }
}
