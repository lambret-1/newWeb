import UIKit
import NaturalLanguage

/// 原生网页翻译管理器
/// 通过 Runtime 调用私有框架 TranslationUIServices.framework 的 LTUITranslationViewController
/// 该 API 与 Safari 内部网页翻译机制一致，仅适用于不上架 App Store 的侧载应用
@objc public class TranslationManager: NSObject {

    public static let shared = TranslationManager()

    /// 翻译视图控制器类（动态获取）
    private var translationVCClass: UIViewController.Type?

    /// 翻译视图控制器实例
    private var translationVC: UIViewController?

    /// 运行时属性列表（用于调试和探索）
    private var propertyNames: [String] = []

    private override init() {
        super.init()
        loadPrivateClass()
    }

    /// 动态加载私有类 LTUITranslationViewController
    private func loadPrivateClass() {
        // 尝试多种类名变体
        let classNames = [
            "LTUITranslationViewController",
            "LTTranslationViewController",
            "TranslationUIServices.LTUITranslationViewController"
        ]
        for name in classNames {
            if let cls = NSClassFromString(name) as? UIViewController.Type {
                translationVCClass = cls
                print("[翻译管理器] 成功加载私有类: \(name)")
                exploreProperties(cls: cls)
                return
            }
        }
        print("[翻译管理器] 警告: 无法加载 LTUITranslationViewController，当前系统可能不支持")
    }

    /// 运行时探索类的所有属性和方法
    private func exploreProperties(cls: AnyClass) {
        var count: UInt32 = 0
        guard let properties = class_copyPropertyList(cls, &count) else { return }
        for i in 0..<Int(count) {
            let property = properties[i]
            if let name = String(utf8String: property_getName(property)) {
                propertyNames.append(name)
            }
        }
        free(properties)
        print("[翻译管理器] 发现 \(propertyNames.count) 个属性: \(propertyNames)")
    }

    /// 检查当前系统是否支持原生翻译
    public func isAvailable() -> Bool {
        return translationVCClass != nil
    }

    /// 获取所有可设置的属性名（用于调试）
    public func availableProperties() -> [String] {
        return propertyNames
    }

    /// 呈现原生翻译界面
    /// - Parameters:
    ///   - text: 待翻译的文本内容
    ///   - sourceLanguage: 源语言（可选，自动检测）
    ///   - targetLanguage: 目标语言（默认简体中文）
    ///   - viewController: 从哪个视图控制器呈现
    ///   - completion: 完成回调
    public func presentTranslation(
        text: String,
        sourceLanguage: String? = nil,
        targetLanguage: String = "zh-Hans",
        from viewController: UIViewController,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        guard let cls = translationVCClass else {
            completion?(false, NSError(domain: "TranslationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "当前系统不支持原生翻译"]))
            return
        }

        // 创建翻译视图控制器实例
        let vc = cls.init()
        translationVC = vc

        // 自动检测源语言
        let detectedLanguage = sourceLanguage ?? detectLanguage(text: text)
        print("[翻译管理器] 源语言: \(detectedLanguage ?? "自动"), 目标语言: \(targetLanguage), 文本长度: \(text.count)")

        // 通过 KVC 设置已知属性（尝试多种可能的属性名）
        setValueIfExists(text, forKeys: ["sourceText", "text", "content", "inputText", "sourceContent"], in: vc)
        setValueIfExists(targetLanguage, forKeys: ["targetLanguage", "targetLocale", "toLanguage", "destinationLanguage"], in: vc)
        if let src = detectedLanguage {
            setValueIfExists(src, forKeys: ["sourceLanguage", "sourceLocale", "fromLanguage", "originLanguage"], in: vc)
        }

        // 尝试设置来源元信息（LTUISourceMeta）
        if let sourceMetaClass = NSClassFromString("LTUISourceMeta") as? NSObject.Type {
            let meta = sourceMetaClass.init()
            setValueIfExists("webpage", forKeys: ["sourceType", "type", "origin"], in: meta)
            vc.setValue(meta, forKey: "sourceMeta")
        }

        // 以模态方式呈现
        vc.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }

        viewController.present(vc, animated: true) {
            print("[翻译管理器] 翻译界面已呈现")
            completion?(true, nil)
        }
    }

    /// 自动检测文本语言
    private func detectLanguage(text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
    }

    /// 尝试设置多个可能的属性名，找到第一个存在的就设置
    private func setValueIfExists(_ value: Any, forKeys keys: [String], in object: NSObject) {
        for key in keys {
            if object.responds(to: Selector(key)) || propertyNames.contains(key) {
                do {
                    try objc_setAssociatedObject(object, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    object.setValue(value, forKey: key)
                    print("[翻译管理器] 成功设置属性: \(key)")
                    return
                } catch {
                    continue
                }
            }
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
