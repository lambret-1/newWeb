import WebKit

/// WKUIDelegate 包装：将长按菜单替换为中文菜单（复制 / 翻译此页 / 下载链接 / 下载图片），
/// 其余 WKUIDelegate 回调原样转发给原 delegate。
class WebViewDelegateWrapper: NSObject, WKUIDelegate {
  weak var original: WKUIDelegate?
  var onMenuAction: ((String, [String: Any]) -> Void)?

  init(original: WKUIDelegate) {
    self.original = original
    super.init()
  }

  // MARK: - 长按菜单（中文）

  func webView(
    _ webView: WKWebView,
    contextMenuConfigurationFor element: WKContextMenuElementInfo,
    completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
  ) {
    let link = element.linkURL?.absoluteString ?? ""
    var children: [UIAction] = []

    children.append(
      UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
        webView.evaluateJavaScript("document.execCommand('copy');") { _, _ in }
      }
    )
    children.append(
      UIAction(
        title: "翻译此页",
        image: UIImage(systemName: "character.book.closed")
      ) { [weak self] _ in
        self?.onMenuAction?("translatePage", [:])
      }
    )
    if !link.isEmpty {
      children.append(
        UIAction(title: "下载链接", image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
          self?.onMenuAction?("download", ["url": link])
        }
      )
    }

    let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      UIMenu(title: "", children: children)
    }
    completionHandler(config)
  }

  // MARK: - 其余 WKUIDelegate 回调转发

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    return original?.webView?(
      webView,
      createWebViewWith: configuration,
      for: navigationAction,
      windowFeatures: windowFeatures
    )
  }

  func webViewDidClose(_ webView: WKWebView) {
    original?.webViewDidClose?(webView)
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void
  ) {
    original?.webView?(
      webView,
      runJavaScriptAlertPanelWithMessage: message,
      initiatedByFrame: frame,
      completionHandler: completionHandler
    )
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (Bool) -> Void
  ) {
    original?.webView?(
      webView,
      runJavaScriptConfirmPanelWithMessage: message,
      initiatedByFrame: frame,
      completionHandler: completionHandler
    )
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String?,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (String?) -> Void
  ) {
    original?.webView?(
      webView,
      runJavaScriptTextInputPanelWithPrompt: prompt,
      defaultText: defaultText,
      initiatedByFrame: frame,
      completionHandler: completionHandler
    )
  }
}
