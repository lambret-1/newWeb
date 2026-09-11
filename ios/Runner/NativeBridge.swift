import Flutter
import UIKit
import WebKit
import QuickLook

/// 原生能力桥：缓存管理 / 内容拦截器 / 下载管理 / 文件预览 / DNS 描述文件。
/// 事件通道（com.newweb/native_events）推送下载进度与长按菜单动作。
public class NativeBridgePlugin: NSObject, FlutterPlugin, QLPreviewControllerDataSource, UIDocumentInteractionControllerDelegate {
  private var eventSink: FlutterEventSink?
  private var previewURL: URL?
  private var documentController: UIDocumentInteractionController?

  // 长截图会话状态（扁平结构，避免深度嵌套闭包导致编译器卡死）
  private var fpWebView: WKWebView?
  private var fpResult: FlutterResult?
  private var fpLogs: [String] = []
  private var fpSegments: [UIImage] = []
  private var fpIndex = 0
  private var fpSegmentCount = 0
  private var fpPageWidth: CGFloat = 0
  private var fpPageHeight: CGFloat = 0
  private var fpViewHeight: CGFloat = 0
  private var fpOutputScale: CGFloat = 1.0
  private var fpOriginalOffset = CGPoint.zero
  private var fpOriginalBounce = true
  private let fpMaxHeight: CGFloat = 10000
  private let fpMaxSegments = 25

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
    case "openWebURL":
      openWebURL(url: args["url"] as? String ?? "", result: result)
    case "captureSnapshot":
      captureSnapshot(url: args["url"] as? String ?? "", result: result)
    case "captureFullPage":
      captureFullPage(url: args["url"] as? String ?? "", result: result)
    case "saveImageToGallery":
      saveImageToGallery(base64: args["base64"] as? String ?? "", result: result)
    case "shareImage":
      shareImage(base64: args["base64"] as? String ?? "", result: result)
    case "exportPDF":
      exportPDF(url: args["url"] as? String ?? "", title: args["title"] as? String ?? "", result: result)
    case "clearWebDataTypes":
      let types = args["types"] as? [String] ?? []
      clearWebDataTypes(types, result: result)
    case "getWebDataRecordCount":
      getWebDataRecordCount(result: result)
    case "clearHttpCache":
      URLCache.shared.removeAllCachedResponses()
      clearCachesDirectory()
      result(true)
    case "translatePage":
      translatePage(
        text: args["text"] as? String ?? "",
        sourceLanguage: args["sourceLanguage"] as? String,
        targetLanguage: args["targetLanguage"] as? String ?? "zh-Hans",
        result: result
      )
    case "isTranslationAvailable":
      result(TranslationManager.shared.isAvailable())
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

  /// 用 UIDocumentInteractionController 弹出打开方式菜单（.mobileconfig 可选择设置/Safari 安装）。
  private func openSystemURL(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    documentController = UIDocumentInteractionController(url: url)
    documentController?.delegate = self
    documentController?.uti = "com.apple.mobileconfig"
    guard let view = topViewController()?.view else {
      result(false)
      return
    }
    documentController?.presentOptionsMenu(from: view.bounds, in: view, animated: true)
    result(true)
  }

  /// 在 Safari 中打开网页 URL。
  private func openWebURL(url: String, result: @escaping FlutterResult) {
    guard let nsUrl = URL(string: url) else {
      result(false)
      return
    }
    UIApplication.shared.open(nsUrl, options: [:]) { success in
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

  // MARK: - 长截图（扁平结构，防闪退/白边）

  private func captureFullPage(url: String, result: @escaping FlutterResult) {
    var logs: [String] = []
    func slog(_ msg: String) { NSLog("[NW-FullPage] \(msg)"); logs.append(msg) }
    slog("captureFullPage 入口, url=\(url)")
    guard let webView = findWebView(for: url, logs: &logs) else {
      result(["error": "找不到 WebView", "logs": logs])
      return
    }
    let js = "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
    webView.evaluateJavaScript(js) { [weak self] heightObj, _ in
      self?.fpStart(webView: webView, heightObj: heightObj, logs: logs, result: result)
    }
  }

  private func fpStart(webView: WKWebView, heightObj: Any?, logs: [String], result: @escaping FlutterResult) {
    var logs = logs
    func slog(_ m: String) { NSLog("[NW-FullPage] \(m)"); logs.append(m) }

    let pageWidth = webView.bounds.width
    let viewHeight = webView.bounds.height
    var pageHeight: CGFloat = 0
    if let n = heightObj as? NSNumber { pageHeight = CGFloat(n.doubleValue) }
    if pageHeight <= 0 { pageHeight = webView.scrollView.contentSize.height }
    guard pageHeight > 0, pageWidth > 0, viewHeight > 0 else {
      result(["error": "页面尺寸异常", "logs": logs]); return
    }
    slog("页面高度=\(pageHeight), 可视=\(viewHeight), 宽=\(pageWidth)")

    // 不超过一屏：单张截图
    if pageHeight <= viewHeight + 1 {
      let cfg = WKSnapshotConfiguration()
      cfg.snapshotWidth = NSNumber(value: pageWidth)
      cfg.afterScreenUpdates = true
      webView.takeSnapshot(with: cfg) { image, _ in
        guard let image = image, let data = image.jpegData(compressionQuality: 0.9) else {
          result(["error": "截图失败", "logs": logs]); return
        }
        result(["base64": data.base64EncodedString(), "logs": logs])
      }
      return
    }

    // 初始化会话
    fpWebView = webView
    fpResult = result
    fpLogs = logs
    fpSegments.removeAll()
    fpIndex = 0
    fpPageWidth = pageWidth
    fpPageHeight = pageHeight
    fpViewHeight = viewHeight
    fpOutputScale = pageHeight > fpMaxHeight ? fpMaxHeight / pageHeight : 1.0
    fpSegmentCount = min(Int(ceil(pageHeight / viewHeight)), fpMaxSegments)
    fpOriginalOffset = webView.scrollView.contentOffset
    fpOriginalBounce = webView.scrollView.bounces
    webView.scrollView.bounces = false
    slog("计划分段=\(fpSegmentCount), 缩放=\(fpOutputScale)")
    fpCaptureNext()
  }

  private func fpCaptureNext() {
    guard let webView = fpWebView, let result = fpResult else { return }
    // 全部截完 -> 拼接
    guard fpIndex < fpSegmentCount else {
      fpFinish()
      return
    }
    let offsetY = CGFloat(fpIndex) * fpViewHeight
    let clampedY = min(offsetY, max(0, fpPageHeight - fpViewHeight))
    webView.scrollView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
    webView.layoutIfNeeded()
    let idx = fpIndex
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
      guard let self = self else { return }
      let cfg = WKSnapshotConfiguration()
      cfg.snapshotWidth = NSNumber(value: self.fpPageWidth)
      cfg.afterScreenUpdates = true
      webView.takeSnapshot(with: cfg) { image, err in
        if let e = err { NSLog("[NW-FullPage] 第\(idx+1)段失败: \(e.localizedDescription)") }
        if let image = image { self.fpSegments.append(image) }
        self.fpIndex += 1
        self.fpCaptureNext()
      }
    }
  }

  private func fpFinish() {
    guard let webView = fpWebView, let result = fpResult else { return }
    // 恢复滚动状态
    webView.scrollView.bounces = fpOriginalBounce
    webView.scrollView.setContentOffset(fpOriginalOffset, animated: false)
    let restoreOffset = fpOriginalOffset
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      webView.scrollView.setContentOffset(restoreOffset, animated: false)
    }
    let image = fpStitch()
    defer { fpCleanup() }
    guard let finalImage = image, let data = finalImage.jpegData(compressionQuality: 0.85) else {
      fpLogs.append("❌ 拼接失败")
      result(["error": "拼接失败", "logs": fpLogs]); return
    }
    fpLogs.append("✅ 完成 尺寸=\(finalImage.size) 段=\(fpSegments.count) \(data.count/1024)KB")
    result(["base64": data.base64EncodedString(), "logs": fpLogs])
  }

  private func fpCleanup() {
    fpWebView = nil
    fpResult = nil
    fpSegments.removeAll()
    fpLogs.removeAll()
  }

  private func fpStitch() -> UIImage? {
    guard !fpSegments.isEmpty else { return nil }
    let pixelWidth = fpSegments[0].size.width * fpSegments[0].scale
    let pointToPixel = pixelWidth / fpPageWidth
    let totalH = fpPageHeight * pointToPixel * fpOutputScale
    let finalSize = CGSize(width: pixelWidth, height: totalH)
    let renderer = UIGraphicsImageRenderer(size: finalSize)
    return renderer.image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: finalSize))
      var y: CGFloat = 0
      for (i, img) in fpSegments.enumerated() {
        let pxH = img.size.height * img.scale
        let h = min(pxH * fpOutputScale, finalSize.height - y)
        if h <= 0 { break }
        img.draw(in: CGRect(x: 0, y: y, width: finalSize.width, height: h))
        y += h
        if y >= finalSize.height { NSLog("[NW-FullPage] 拼接到第\(i+1)段到底"); break }
      }
    }
  }


  // MARK: - 保存到相册

  private func saveImageToGallery(base64: String, result: @escaping FlutterResult) {
    guard let data = Data(base64Encoded: base64),
          let image = UIImage(data: data) else {
      result(["success": false, "error": "图片解码失败"])
      return
    }
    // 使用完成回调确保保存成功后再返回
    let selector = #selector(image(_:didFinishSavingWithError:contextInfo:))
    UIImageWriteToSavedPhotosAlbum(image, self, selector, nil)
    // 保存回调会异步触发，这里先返回成功（实际结果在回调中记录）
    result(["success": true])
  }

  @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    if let error = error {
      NSLog("[NW-Save] 保存相册失败: \(error.localizedDescription)")
    } else {
      NSLog("[NW-Save] 保存相册成功")
    }
  }

  // MARK: - 分享图片

  private func shareImage(base64: String, result: @escaping FlutterResult) {
    guard let data = Data(base64Encoded: base64),
          let image = UIImage(data: data) else {
      result(["success": false, "error": "图片解码失败"])
      return
    }
    DispatchQueue.main.async {
      let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = UIApplication.shared.keyWindow?.rootViewController?.view
        popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      UIApplication.shared.keyWindow?.rootViewController?.present(activityVC, animated: true)
      result(["success": true])
    }
  }

  // MARK: - 导出网页为 PDF

  private func exportPDF(url: String, title: String, result: @escaping FlutterResult) {
    var logs: [String] = []
    func slog(_ msg: String) {
      NSLog("[NW-PDF] \(msg)")
      logs.append(msg)
    }
    slog("exportPDF 入口, url=\(url)")
    guard let webView = findWebView(for: url, logs: &logs) else {
      slog("❌ 找不到 WKWebView")
      result(["error": "找不到 WebView", "logs": logs])
      return
    }

    let config = WKPDFConfiguration()
    config.rect = CGRect(x: 0, y: 0, width: webView.scrollView.contentSize.width, height: webView.scrollView.contentSize.height)

    webView.createPDF(configuration: config) { pdfResult in
      switch pdfResult {
      case .success(let pdfData):
        slog("✅ PDF 生成成功, size=\(pdfData.count) bytes")
        // 保存到临时文件
        let dir = FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask).first!
          .appendingPathComponent("PDFExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeTitle = title.isEmpty ? "网页" : title.replacingOccurrences(of: "/", with: "_")
        let file = dir.appendingPathComponent("\(safeTitle).pdf")
        do {
          try pdfData.write(to: file)
          slog("✅ PDF 已保存: \(file.path)")
          // 弹出分享面板
          DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
              popover.sourceView = UIApplication.shared.keyWindow?.rootViewController?.view
              popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
              popover.permittedArrowDirections = []
            }
            UIApplication.shared.keyWindow?.rootViewController?.present(activityVC, animated: true)
          }
          result(["success": true, "path": file.path, "logs": logs])
        } catch {
          slog("❌ PDF 保存失败: \(error.localizedDescription)")
          result(["error": error.localizedDescription, "logs": logs])
        }
      case .failure(let error):
        slog("❌ PDF 生成失败: \(error.localizedDescription)")
        result(["error": error.localizedDescription, "logs": logs])
      }
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

  // MARK: - 原生网页翻译（LTUITranslationViewController 私有 API）

  private func translatePage(
    text: String,
    sourceLanguage: String?,
    targetLanguage: String,
    result: @escaping FlutterResult
  ) {
    guard !text.isEmpty else {
      result(FlutterError(code: "EMPTY_TEXT", message: "待翻译文本为空", details: nil))
      return
    }
    guard TranslationManager.shared.isAvailable() else {
      result(FlutterError(code: "NOT_AVAILABLE", message: "当前系统不支持原生翻译", details: nil))
      return
    }

    // 获取当前最顶层的视图控制器
    guard let rootVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "NO_ROOT_VC", message: "无法获取根视图控制器", details: nil))
      return
    }
    var topVC = rootVC
    while let presented = topVC.presentedViewController {
      topVC = presented
    }

    TranslationManager.shared.presentTranslation(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      from: topVC
    ) { success, error in
      if success {
        result(true)
      } else {
        result(FlutterError(code: "TRANSLATE_FAILED", message: error?.localizedDescription ?? "翻译失败", details: nil))
      }
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
