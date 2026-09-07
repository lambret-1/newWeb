import Flutter
import UIKit
import WebKit
import QuickLook

/// 原生能力桥：缓存管理 / 内容拦截器 / 下载管理 / 文件预览 / DNS 描述文件。
/// 事件通道（com.newweb/native_events）推送下载进度与长按菜单动作。
public class NativeBridgePlugin: NSObject, FlutterPlugin, QLPreviewControllerDataSource {
  private var eventSink: FlutterEventSink?
  private var previewURL: URL?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.newweb/native",
      binaryMessenger: registrar.messenger()
    )
    let events = FlutterEventChannel(
      name: "com.newweb/native_events",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    events.setStreamHandler(instance)

    ContentBlockerManager.shared.onMenuAction = { [weak instance] action, payload in
      instance?.sendEvent(action, payload)
    }
    DownloadManager.shared.onEvent = { [weak instance] event, payload in
      instance?.sendEvent("download_\(event)", payload)
    }
  }

  private func sendEvent(_ name: String, _ payload: [String: Any]) {
    var dict = payload
    dict["event"] = name
    eventSink?(dict)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      if call.method == "getCacheSize" || call.method == "clearWebData" || call.method == "generateDNSProfile" {
        handleNoArg(call, result: result)
        return
      }
      result(FlutterMethodNotImplemented)
      return
    }
    switch call.method {
    case "injectContentBlocker":
      let rules = args["rules"] as? String ?? "[]"
      ContentBlockerManager.shared.inject(rulesJson: rules) { ok in
        result(ok)
      }
    case "startDownload":
      DownloadManager.shared.start(
        url: args["url"] as? String ?? "",
        taskId: args["taskId"] as? String ?? ""
      )
      result(true)
    case "pauseDownload":
      DownloadManager.shared.pause(taskId: args["taskId"] as? String ?? "")
      result(true)
    case "resumeDownload":
      DownloadManager.shared.resume(
        taskId: args["taskId"] as? String ?? "",
        url: args["url"] as? String ?? ""
      )
      result(true)
    case "cancelDownload":
      DownloadManager.shared.cancel(taskId: args["taskId"] as? String ?? "")
      result(true)
    case "previewFile":
      previewFile(path: args["path"] as? String ?? "")
      result(true)
    case "openSystemURL":
      openSystemURL(path: args["path"] as? String ?? "", result: result)
    case "captureSnapshot":
      captureSnapshot(url: args["url"] as? String ?? "", result: result)
    case "clearWebDataTypes":
      let types = args["types"] as? [String] ?? []
      clearWebDataTypes(types, result: result)
    case "getWebDataRecordCount":
      getWebDataRecordCount(result: result)
    case "clearHttpCache":
      URLCache.shared.removeAllCachedResponses()
      clearCachesDirectory()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleNoArg(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "clearWebData":
      clearWebData(result: result)
    case "getCacheSize":
      getCacheSize(result: result)
    case "generateDNSProfile":
      result(generateDNSProfile())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 缓存管理

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

  private func getCacheSize(result: @escaping FlutterResult) {
    result(cacheDirectorySize())
  }

  /// 按指定类型清空网站数据。
  private func clearWebDataTypes(
    _ types: [String],
    result: @escaping FlutterResult
  ) {
    guard !types.isEmpty else {
      result(true)
      return
    }
    let typeSet = Set(types)
    let store = WKWebsiteDataStore.default()
    store.fetchDataRecords(ofTypes: typeSet) { records in
      store.removeData(ofTypes: typeSet, for: records) {
        result(true)
      }
    }
  }

  /// 网站数据记录总数。
  private func getWebDataRecordCount(result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default()
    store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
      result(records.count)
    }
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

  // MARK: - 文件预览（QLPreviewController）

  private func previewFile(path: String) {
    previewURL = URL(fileURLWithPath: path)
    let preview = QLPreviewController()
    preview.dataSource = self
    topViewController()?.present(preview, animated: true)
  }

  /// 用系统默认方式打开文件（如 .mobileconfig 会自动弹出设置应用安装）。
  private func openSystemURL(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    UIApplication.shared.open(url, options: [:]) { success in
      result(success)
    }
  }

  public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    previewURL == nil ? 0 : 1
  }

  public func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    (previewURL ?? URL(fileURLWithPath: "/")) as NSURL
  }

  private func topViewController(
    base: UIViewController? = nil
  ) -> UIViewController? {
    let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
    let root = base ?? keyWindow?.rootViewController
    if let nav = root as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(base: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(base: presented)
    }
    return root
  }

  // MARK: - 标签快照（截取 WKWebView 快照）

  /// 截取目标标签快照：优先按 URL 匹配，其次取可见 WebView。
  /// PNG 写入沙盒 Caches/Snapshots（避免大消息传输），返回 {path, url}。
  private func captureSnapshot(url: String, result: @escaping FlutterResult) {
    var logs: [String] = []
    func slog(_ msg: String) {
      NSLog("[NW-Snapshot] \(msg)")
      logs.append(msg)
    }
    slog("captureSnapshot 入口, url=\(url)")
    guard let webView = findWebView(for: url, logs: &logs) else {
      slog("❌ findWebView 返回 nil，找不到 WKWebView")
      result(["logs": logs])
      return
    }
    slog("✅ 找到 WKWebView, webView.url=\(webView.url?.absoluteString ?? "nil"), frame=\(webView.frame)")
    let config = WKSnapshotConfiguration()
    config.snapshotWidth = NSNumber(value: 180)
    webView.takeSnapshot(with: config) { [weak self] image, error in
      if let error = error {
        slog("❌ takeSnapshot 失败, error=\(error.localizedDescription)")
        result(["logs": logs])
        return
      }
      guard let self = self, let image = image else {
        slog("❌ takeSnapshot 返回 image=nil")
        result(["logs": logs])
        return
      }
      slog("✅ takeSnapshot 成功, image.size=\(image.size)")
      guard let data = image.pngData() else {
        slog("❌ pngData 失败")
        result(["logs": logs])
        return
      }
      slog("pngData 成功, data.count=\(data.count) bytes")
      // 直接 base64 返回 Dart，由 Dart 写入 AppSupport（彻底绕开 Swift 写文件权限问题）
      let base64 = data.base64EncodedString()
      slog("✅ base64 编码成功, base64.count=\(base64.count)")
      result(["base64": base64, "url": webView.url?.absoluteString ?? "", "logs": logs])
    }
  }

  /// 查找当前可见的 WKWebView。
  /// 从 keyWindow.rootViewController 开始，穿透 childViewControllers 和 presentedViewController，
  /// 因为 Flutter 平台视图放在 ViewController 容器中，单纯遍历 view.subviews 找不到。
  private func findWebView(for url: String, logs: inout [String]) -> WKWebView? {
    guard let window = UIApplication.shared.keyWindow,
          let rootVC = window.rootViewController else {
      logs.append("❌ 找不到 keyWindow 或 rootViewController")
      return nil
    }
    logs.append("findWebView 从 rootViewController 开始遍历: \(String(describing: rootVC))")
    return findWebViewInVC(rootVC, logs: &logs)
  }

  private func findWebViewInVC(_ vc: UIViewController, logs: inout [String]) -> WKWebView? {
    logs.append("VC: \(String(describing: vc)), children.count=\(vc.children.count), view.subviews.count=\(vc.view.subviews.count)")
    // 1. 在当前 VC 的 view 层级中找
    if let found = findVisibleWebView(in: vc.view, depth: 0, logs: &logs) {
      logs.append("✅ 在 VC \(String(describing: vc)) 的 view 中找到 WKWebView")
      return found
    }
    // 2. 穿透 childViewControllers
    for child in vc.children {
      if let found = findWebViewInVC(child, logs: &logs) {
        return found
      }
    }
    // 3. 穿透 presentedViewController
    if let presented = vc.presentedViewController {
      if let found = findWebViewInVC(presented, logs: &logs) {
        return found
      }
    }
    return nil
  }

  private func findVisibleWebView(in view: UIView, depth: Int, logs: inout [String]) -> WKWebView? {
    if depth > 20 { return nil }
    let indent = String(repeating: "  ", count: depth)
    logs.append("\(indent)\(type(of: view)) frame=\(view.frame) hidden=\(view.isHidden)")
    if let wv = view as? WKWebView {
      logs.append("\(indent)✅ 是 WKWebView! isHidden=\(wv.isHidden), frame=\(wv.frame), alpha=\(wv.alpha)")
      if !wv.isHidden && wv.frame.width > 1 && wv.alpha > 0.1 {
        return wv
      }
      logs.append("\(indent)⚠️ WKWebView 不可见，跳过")
      return nil
    }
    for sub in view.subviews {
      if let found = findVisibleWebView(in: sub, depth: depth + 1, logs: &logs) {
        return found
      }
    }
    return nil
  }

  // MARK: - DNS 描述文件（AdGuard DNS）

  private func generateDNSProfile() -> String? {
    let uuid1 = UUID().uuidString
    let uuid2 = UUID().uuidString
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>PayloadContent</key>
      <array>
        <dict>
          <key>PayloadDescription</key>
          <string>将系统 DNS 配置为 AdGuard DNS（广告与追踪拦截）</string>
          <key>PayloadDisplayName</key>
          <string>AdGuard DNS</string>
          <key>PayloadIdentifier</key>
          <string>com.newweb.dns.adguard</string>
          <key>PayloadType</key>
          <string>com.apple.dnsSettings.managed</string>
          <key>PayloadUUID</key>
          <string>\(uuid1)</string>
          <key>PayloadVersion</key>
          <integer>1</integer>
          <key>ProxiedContentFilterRules</key>
          <array>
            <dict>
              <key>ProviderBundleIdentifier</key>
              <string>com.apple.SystemConfiguration.dns-settings</string>
            </dict>
          </array>
          <key>ServerName</key>
          <string>AdGuard DNS</string>
          <key>DNSSettings</key>
          <dict>
            <key>DNSProtocol</key>
            <string>HTTPS</string>
            <key>ServerURL</key>
            <string>https://dns.adguard-dns.com/dns-query</string>
          </dict>
        </dict>
      </array>
      <key>PayloadDisplayName</key>
      <string>AdGuard DNS 配置</string>
      <key>PayloadIdentifier</key>
      <string>com.newweb.dns</string>
      <key>PayloadType</key>
      <string>Configuration</string>
      <key>PayloadUUID</key>
      <string>\(uuid2)</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
    </plist>
    """
    let dir = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("DNS", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("AdGuardDNS_配置.mobileconfig")
    do {
      try xml.write(to: file, atomically: true, encoding: .utf8)
      return file.path
    } catch {
      return nil
    }
  }
}

extension NativeBridgePlugin: FlutterStreamHandler {
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
