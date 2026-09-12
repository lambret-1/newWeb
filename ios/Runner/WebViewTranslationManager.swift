import WebKit

/// WKWebView 私有翻译 API 管理器
/// 通过 Runtime 访问 Safari 同源的整页翻译能力
/// 仅适用于 iOS 15+ 不上架 App Store 的侧载应用
@objc public class WebViewTranslationManager: NSObject {

    public static let shared = WebViewTranslationManager()

    /// 运行时缓存的方法名
    private var translationMethods: [String] = []
    private var didExplore = false

    private override init() {
        super.init()
    }

    /// 检查当前 WKWebView 是否支持私有翻译 API
    public func isAvailable(in webView: WKWebView) -> Bool {
        // 必须 iOS 15+
        guard #available(iOS 15.0, *) else { return false }

        // 尝试访问 _page 属性
        guard let page = safeValue(forKey: "_page", object: webView) else {
            print("[WebView翻译] 无法访问 _page 属性")
            return false
        }

        // 尝试访问 _translation 属性
        guard let translation = safeValue(forKey: "_translation", object: page as AnyObject) else {
            print("[WebView翻译] 无法访问 _translation 属性")
            return false
        }

        // 探索翻译对象的方法
        if !didExplore {
            exploreMethods(of: type(of: translation as AnyObject))
            didExplore = true
        }

        return true
    }

    /// 请求整页翻译
    /// - Parameters:
    ///   - webView: 目标 WKWebView
    ///   - targetLocale: 目标语言（默认 zh-Hans）
    ///   - completion: 完成回调
    public func requestTranslation(
        in webView: WKWebView,
        targetLocale: String = "zh-Hans",
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard #available(iOS 15.0, *) else {
            completion(false, "iOS 版本低于 15")
            return
        }

        print("[WebView翻译] 开始请求翻译，目标语言: \(targetLocale)")

        // 1. 获取 _page
        guard let page = safeValue(forKey: "_page", object: webView) else {
            completion(false, "无法访问 _page")
            return
        }
        print("[WebView翻译] 获取 _page 成功: \(type(of: page))")

        // 2. 获取 _translation
        guard let translation = safeValue(forKey: "_translation", object: page as AnyObject) else {
            completion(false, "无法访问 _translation")
            return
        }
        print("[WebView翻译] 获取 _translation 成功: \(type(of: translation))")

        // 3. 探索方法（首次）
        if !didExplore {
            exploreMethods(of: type(of: translation as AnyObject))
            didExplore = true
        }

        // 4. 尝试调用各种可能的翻译方法
        let translationObj = translation as AnyObject

        // 尝试方法1: _requestTranslationWithSourceLocale:targetLocale:userInitiated:completionHandler:
        if let result = tryPerformTranslation(
            translationObj,
            selector: "_requestTranslationWithSourceLocale:targetLocale:userInitiated:completionHandler:",
            targetLocale: targetLocale
        ) {
            completion(result, nil)
            return
        }

        // 尝试方法2: requestTranslationWithSourceLocale:targetLocale:completionHandler:
        if let result = tryPerformTranslation(
            translationObj,
            selector: "requestTranslationWithSourceLocale:targetLocale:completionHandler:",
            targetLocale: targetLocale
        ) {
            completion(result, nil)
            return
        }

        // 尝试方法3: _requestTranslation:
        if translationObj.responds(to: Selector("_requestTranslation:")) {
            let sel = Selector("_requestTranslation:")
            translationObj.perform(sel, with: targetLocale)
            print("[WebView翻译] 调用 _requestTranslation: 成功")
            completion(true, nil)
            return
        }

        // 尝试方法4: translate:
        if translationObj.responds(to: Selector("translate:")) {
            let sel = Selector("translate:")
            translationObj.perform(sel, with: targetLocale)
            print("[WebView翻译] 调用 translate: 成功")
            completion(true, nil)
            return
        }

        completion(false, "未找到可用的翻译方法，可用方法: \(translationMethods)")
    }

    /// 尝试执行翻译方法（带 completionHandler 的版本）
    private func tryPerformTranslation(
        _ obj: AnyObject,
        selector: String,
        targetLocale: String
    ) -> Bool? {
        let sel = Selector(selector)
        guard obj.responds(to: sel) else { return nil }

        print("[WebView翻译] 尝试调用方法: \(selector)")

        // 使用 objc_msgSend 动态调用
        typealias TranslationFunction = @convention(c) (
            AnyObject, Selector, NSString?, NSString, Bool, @escaping (Bool, Error?) -> Void
        ) -> Void

        let impl = class_getMethodImplementation(object_getClass(obj), sel)
        guard let functionImpl = impl else { return nil }
        let function = unsafeBitCast(functionImpl, to: TranslationFunction.self)

        var success = false
        let semaphore = DispatchSemaphore(value: 0)

        function(obj, sel, nil, targetLocale as NSString, true) { result, error in
            success = result
            if let error = error {
                print("[WebView翻译] 翻译完成但有错误: \(error.localizedDescription)")
            } else {
                print("[WebView翻译] 翻译请求成功")
            }
            semaphore.signal()
        }

        // 等待最多 2 秒
        _ = semaphore.wait(timeout: .now() + 2)
        return success
    }

    /// 安全获取 KVC 值（不存在的 key 返回 nil，不崩溃）
    private func safeValue(forKey key: String, object: AnyObject) -> Any? {
        do {
            return try object.value(forKey: key)
        } catch {
            print("[WebView翻译] 获取属性 \(key) 失败: \(error)")
            return nil
        }
    }

    /// 运行时探索类的所有方法
    private func exploreMethods(of cls: AnyClass) {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &count) else { return }
        for i in 0..<Int(count) {
            let sel = method_getName(methods[i])
            let name = NSStringFromSelector(sel)
            translationMethods.append(name)
        }
        free(methods)
        print("[WebView翻译] 发现 \(translationMethods.count) 个方法: \(translationMethods.prefix(30))")
    }

    /// 获取调试信息
    public func debugInfo(for webView: WKWebView) -> [String: Any] {
        var info: [String: Any] = [
            "iOS15+": #available(iOS 15.0, *)
        ]
        if let page = safeValue(forKey: "_page", object: webView) {
            info["pageClass"] = NSStringFromClass(type(of: page as AnyObject))
            if let translation = safeValue(forKey: "_translation", object: page as AnyObject) {
                info["translationClass"] = NSStringFromClass(type(of: translation as AnyObject))
                info["translationMethods"] = translationMethods
            } else {
                info["translationClass"] = "nil"
            }
        } else {
            info["pageClass"] = "nil"
        }
        return info
    }
}
