import UIKit
import NaturalLanguage

/// 原生网页翻译管理器
/// 通过 Runtime 调用私有框架 TranslationUIServices.framework
/// 仅适用于不上架 App Store 的侧载应用
@objc public class TranslationManager: NSObject {

    public static let shared = TranslationManager()

    /// 翻译视图控制器类（动态获取，懒加载）
    private var cachedClass: AnyClass?
    private var didCheckClass = false

    private override init() {
        super.init()
        // 不在 init 中做任何可能崩溃的操作
    }

    /// 懒加载获取翻译类（线程安全）
    private func getTranslationClass() -> AnyClass? {
        if didCheckClass { return cachedClass }
        didCheckClass = true

        let classNames = [
            "LTUITranslationViewController",
            "LTTranslationViewController",
            "TranslationViewController"
        ]
        for name in classNames {
            if let cls = NSClassFromString(name) {
                cachedClass = cls
                print("[翻译管理器] 找到类: \(name)")
                break
            }
        }
        if cachedClass == nil {
            print("[翻译管理器] 未找到翻译视图控制器类")
        }
        return cachedClass
    }

    /// 检查当前系统是否支持原生翻译
    public func isAvailable() -> Bool {
        return getTranslationClass() != nil
    }

    /// 呈现原生翻译界面
    public func presentTranslation(
        text: String,
        sourceLanguage: String? = nil,
        targetLanguage: String = "zh-Hans",
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let cls = getTranslationClass() else {
            let error = NSError(domain: "TranslationManager", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "当前系统不支持原生翻译"])
            completion(false, error)
            return
        }

        print("[翻译管理器] 开始创建翻译视图控制器")

        // 只使用最安全的 init 方式
        guard let vcClass = cls as? UIViewController.Type else {
            let error = NSError(domain: "TranslationManager", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "类不是 UIViewController 类型"])
            completion(false, error)
            return
        }

        let vc = vcClass.init()
        print("[翻译管理器] 视图控制器创建成功: \(type(of: vc))")

        // 自动检测源语言
        let detectedLanguage = sourceLanguage ?? detectLanguage(text: text)
        print("[翻译管理器] 源语言: \(detectedLanguage ?? "自动"), 目标: \(targetLanguage)")

        // 安全设置属性（用 try-catch 包裹，只设置已知存在的 key）
        safeSetValue(vc, key: "sourceText", value: text as NSString)
        safeSetValue(vc, key: "text", value: text as NSString)
        safeSetValue(vc, key: "targetLanguage", value: targetLanguage as NSString)
        if let src = detectedLanguage {
            safeSetValue(vc, key: "sourceLanguage", value: src as NSString)
        }

        // 以模态方式呈现
        vc.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }

        DispatchQueue.main.async {
            viewController.present(vc, animated: true) {
                print("[翻译管理器] 翻译界面已呈现")
                completion(true, nil)
            }
        }
    }

    /// 安全设置 KVC 属性（不存在的 key 不会崩溃）
    private func safeSetValue(_ object: NSObject, key: String, value: Any) {
        do {
            try object.setValue(value, forKey: key)
            print("[翻译管理器] 设置属性成功: \(key)")
        } catch {
            // 忽略不存在的 key
        }
    }

    /// 自动检测文本语言
    private func detectLanguage(text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
    }
}
