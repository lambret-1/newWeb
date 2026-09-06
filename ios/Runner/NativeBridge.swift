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
        URLCache.shared.removeAllCachedResponses()
        self.clearCachesDirectory()
        result(true)
      }
    }
  }

  /// 计算网站缓存大小（字节）：统计沙盒 Caches 目录。
  private func getCacheSize(result: @escaping FlutterResult) {
    result(cacheDirectorySize())
  }

  private func cacheDirectorySize() -> Int {
    guard let caches = FileManager.default.urls(
      for: .cachesDirectory, in: .userDomainMask
    ).first else { return 0 }
    let enumerator = FileManager.default.enumerator(
      at: caches,
      includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
    )
    var total: Int64 = 0
    while let url = enumerator?.nextObject() as? URL {
      guard let values = try? url.resourceValues(
        forKeys: [.fileSizeKey, .isDirectoryKey]
      ) else { continue }
      if values.isDirectory == true { continue }
      if let size = values.fileSize {
        total += Int64(size)
      }
    }
    return Int(total)
  }

  private func clearCachesDirectory() {
    guard let caches = FileManager.default.urls(
      for: .cachesDirectory, in: .userDomainMask
    ).first else { return }
    let enumerator = FileManager.default.enumerator(
      at: caches,
      includingPropertiesForKeys: [.isDirectoryKey]
    )
    while let url = enumerator?.nextObject() as? URL {
      guard let values = try? url.resourceValues(
        forKeys: [.isDirectoryKey]
      ) else { continue }
      if values.isDirectory == true { continue }
      try? FileManager.default.removeItem(at: url)
    }
  }
}
