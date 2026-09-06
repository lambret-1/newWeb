import Flutter
import UIKit
import WebKit

/// 原生能力桥：缓存管理（后续扩展离线保存 / 原生翻译等）。
public class NativeBridgePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.newweb/native",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "clearWebData":
      clearWebData(result: result)
    case "getCacheSize":
      getCacheSize(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 清空全部网站数据（Cookie / 缓存 / localStorage 等）。
  private func clearWebData(result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default()
    store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
      store.removeData(
        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
        for: records
      ) {
        result(true)
      }
    }
  }

  /// 计算网站缓存大小（字节）。
  private func getCacheSize(result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default()
    store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
      var total: Int64 = 0
      for record in records {
        total += record.sizeInBytes
      }
      result(Int(total))
    }
  }
}
