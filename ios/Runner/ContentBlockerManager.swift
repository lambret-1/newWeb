import UIKit
import WebKit

/// 内容拦截器管理：编译 WKContentRuleList 并注入所有 WKWebView。
/// 同时负责给 WKWebView 包装中文长按菜单（WKUIDelegate 包装）。
class ContentBlockerManager: NSObject {
  static let shared = ContentBlockerManager()

  private var injectedWebViews = NSHashTable<WKWebView>.weakObjects()
  private var wrappedUIDelegates = NSHashTable<WKWebView>.weakObjects()

  /// 长按菜单动作回调（由 NativeBridgePlugin 注入，转发给 Dart）。
  var onMenuAction: ((String, [String: Any]) -> Void)?

  func inject(rulesJson: String, completion: @escaping (Bool) -> Void) {
    WKContentRuleListStore.default().compileContentRuleList(
      identifier: "com.newweb.adblock",
      encodedContentRuleList: rulesJson
    ) { [weak self] list, error in
      guard let self = self, let list = list, error == nil else {
        completion(false)
        return
      }
      var count = 0
      for window in UIApplication.shared.windows {
        count += self.apply(list, to: window)
      }
      completion(count > 0)
    }
  }

  @discardableResult
  private func apply(_ list: WKContentRuleList, to view: UIView) -> Int {
    var count = 0
    if let webView = view as? WKWebView {
      if !injectedWebViews.contains(webView) {
        webView.configuration.userContentController.add(list)
        injectedWebViews.add(webView)
        count += 1
      }
      wrapUIDelegateIfNeeded(webView)
    }
    for sub in view.subviews {
      count += apply(list, to: sub)
    }
    return count
  }

  /// 包装 WKUIDelegate：替换长按菜单为中文菜单，转发其余回调。
  private func wrapUIDelegateIfNeeded(_ webView: WKWebView) {
    if wrappedUIDelegates.contains(webView) { return }
    guard let original = webView.uiDelegate else { return }
    let wrapper = WebViewDelegateWrapper(original: original)
    wrapper.onMenuAction = onMenuAction
    webView.uiDelegate = wrapper
    wrappedUIDelegates.add(webView)
  }
}
