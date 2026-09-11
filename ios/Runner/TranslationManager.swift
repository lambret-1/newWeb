import UIKit
import NaturalLanguage

/// 原生网页翻译管理器
/// 通过 Runtime 调用私有框架 TranslationUIServices.framework
/// 仅适用于不上架 App Store 的侧载应用
@objc public class TranslationManager: NSObject {

    public static let shared = TranslationManager()

    /// 翻译视图控制器类（动态获取）
    private var translationVCClass: AnyClass?

    /// 翻译视图控制器实例
    private var translationVC: UIViewController?

    /// 运行时属性列表
    private var propertyNames: [String] = []

    /// 运行时方法列表
    private var methodNames: [String] = []

    /// 框架是否已加载
    private var frameworkLoaded = false

    private override init() {
        super.init()
        loadFramework()
        loadPrivateClass()
    }

    /// 手动加载私有框架
    private func loadFramework() {
        let frameworkPaths = [
            "/System/Library/PrivateFrameworks/TranslationUIServices.framework/TranslationUIServices",
            "/System/Library/PrivateFrameworks/Translation.framework/Translation",
            "/System/Library/Frameworks/TranslationUI.framework/TranslationUI"
        ]
        for path in frameworkPaths {
            if let handle = dlopen(path, RTLD_NOW) {
                frameworkLoaded = true
                print("[翻译管理器] 成功加载框架: \(path)")
                break
            } else {
                let error = String(cString: dlerror())
                print("[翻译管理器] 加载框架失败 \(path): \(error)")
            }
        }
        if !frameworkLoaded {
            print("[翻译管理器] 所有框架路径加载失败")
        }
    }

    /// 动态加载私有类
    private func loadPrivateClass() {
        let classNames = [
            "LTUITranslationViewController",
            "LTTranslationViewController",
            "TranslationViewController",
            "LTUINavigationController",
            "LTUITranslationRootViewController"
        ]
        for name in classNames {
            if let cls = NSClassFromString(name) {
                translationVCClass = cls
                print("[翻译管理器] 成功加载私有类: \(name)")
                exploreClass(cls: cls)
                return
            }
        }
        print("[翻译管理器] 警告: 无法加载任何翻译视图控制器类")
    }

    /// 运行时探索类的所有属性和方法
    private func exploreClass(cls: AnyClass) {
        var propCount: UInt32 = 0
        if let properties = class_copyPropertyList(cls, &propCount) {
            for i in 0..<Int(propCount) {
                if let name = String(utf8String: property_getName(properties[i])) {
                    propertyNames.append(name)
                }
            }
            free(properties)
        }
        var methodCount: UInt32 = 0
        if let methods = class_copyMethodList(cls, &methodCount) {
            for i in 0..<Int(methodCount) {
                let sel = method_getName(methods[i])
                methodNames.append(NSStringFromSelector(sel))
            }
            free(methods)
        }
        print("[翻译管理器] 属性(\(propertyNames.count)): \(propertyNames)")
        print("[翻译管理器] 方法(\(methodNames.count)): \(methodNames.prefix(30))")
    }

    /// 检查当前系统是否支持原生翻译
    public func isAvailable() -> Bool {
        return translationVCClass != nil
    }

    /// 获取调试信息
    public func debugInfo() -> [String: Any] {
        return [
            "frameworkLoaded": frameworkLoaded,
            "classFound": translationVCClass != nil,
            "className": NSStringFromClass(translationVCClass ?? NSNull.self),
            "properties": propertyNames,
            "methods": Array(methodNames.prefix(50))
        ]
    }

    /// 呈现原生翻译界面
    public func presentTranslation(
        text: String,
        sourceLanguage: String? = nil,
        targetLanguage: String = "zh-Hans",
        from viewController: UIViewController,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        guard let cls = translationVCClass else {
            let error = NSError(domain: "TranslationManager", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "当前系统不支持原生翻译（类未找到）"])
            completion?(false, error)
            return
        }

        print("[翻译管理器] 开始创建翻译视图控制器，类: \(NSStringFromClass(cls))")

        // 尝试多种初始化方式
        var vc: UIViewController?

        // 方式1: 普通 init
        if let initCls = cls as? UIViewController.Type {
            vc = initCls.init()
            print("[翻译管理器] 使用 init() 创建成功")
        }

        // 方式2: 通过 initWithCoder
        if vc == nil {
            if let obj = cls.alloc() as? UIViewController {
                vc = obj
                print("[翻译管理器] 使用 alloc 创建成功")
            }
        }

        guard let translationVC = vc else {
            let error = NSError(domain: "TranslationManager", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无法创建翻译视图控制器实例"])
            completion?(false, error)
            return
        }

        self.translationVC = translationVC

        // 自动检测源语言
        let detectedLanguage = sourceLanguage ?? detectLanguage(text: text)
        print("[翻译管理器] 源语言: \(detectedLanguage ?? "自动"), 目标: \(targetLanguage), 文本长度: \(text.count)")

        // 通过 KVC 设置所有可能的属性
        let textKeys = ["sourceText", "text", "content", "inputText", "sourceContent",
                        "textToTranslate", "originalText", "string"]
        let targetKeys = ["targetLanguage", "targetLocale", "toLanguage",
                          "destinationLanguage", "targetLanguageCode"]
        let sourceKeys = ["sourceLanguage", "sourceLocale", "fromLanguage",
                          "originLanguage", "sourceLanguageCode"]

        setValueIfExists(text, forKeys: textKeys, in: translationVC)
        setValueIfExists(targetLanguage, forKeys: targetKeys, in: translationVC)
        if let src = detectedLanguage {
            setValueIfExists(src, forKeys: sourceKeys, in: translationVC)
        }

        // 尝试调用常见的配置方法
        performIfResponds(translationVC, selector: "setSourceText:", object: text as NSString)
        performIfResponds(translationVC, selector: "setText:", object: text as NSString)
        performIfResponds(translationVC, selector: "setTargetLanguage:", object: targetLanguage as NSString)

        // 以模态方式呈现
        translationVC.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = translationVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }

        DispatchQueue.main.async {
            viewController.present(translationVC, animated: true) {
                print("[翻译管理器] 翻译界面已呈现")
                completion?(true, nil)
            }
        }
    }

    /// 自动检测文本语言
    private func detectLanguage(text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
    }

    /// 尝试设置多个可能的属性名
    private func setValueIfExists(_ value: Any, forKeys keys: [String], in object: NSObject) {
        for key in keys {
            if propertyNames.contains(key) {
                do {
                    object.setValue(value, forKey: key)
                    print("[翻译管理器] 成功设置属性: \(key)")
                    return
                } catch {
                    print("[翻译管理器] 设置属性失败 \(key): \(error)")
                }
            }
        }
    }

    /// 尝试调用方法
    private func performIfResponds(_ object: NSObject, selector: String, object arg: Any?) {
        let sel = Selector(selector)
        if object.responds(to: sel) {
            object.perform(sel, with: arg)
            print("[翻译管理器] 成功调用方法: \(selector)")
        }
    }

    /// 关闭翻译界面
    public func dismissTranslation(completion: (() -> Void)? = nil) {
        translationVC?.dismiss(animated: true) { [weak self] in
            self?.translationVC = nil
            completion?()
        }
    }
}
