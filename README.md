# 未来浏览器 — 轻量 iOS 浏览器（Flutter + WKWebView 混合开发）

Flutter 3.47.x + [webview_flutter](https://pub.dev/packages/webview_flutter) 4.14.x 构建的 iOS 浏览器（工程名 NewWeb）。
iOS 底层为系统 WKWebView（App Store 对浏览器的强制要求），Flutter 提供壳 UI 与业务逻辑。

- **目标系统**：iOS 15.0+
- **仓库**：由 Webplus（原生 Swift 版）平行发展出的混合技术栈版本，后续功能逐步对齐

## 当前进度（M1 骨架）

已实现：

- **多标签页**：最多 8 个，网格切换 / 关闭 / 新建，后台标签保活
- **手势导航**：左边缘右滑返回、右边缘左滑前进（60pt / 0.7s 阈值，与页面滚动共存）
- **下拉刷新**：页面顶部下拉触发，自绘指示器
- **书签**：默认书签（百度 / GitHub / 哔哩哔哩）、添加到书签、长按或按钮删除（SQLite 存储）
- **历史记录**：自动记录访问历史（30 秒内去重）、相对时间显示、一键清空（上限 1000 条）
- **地址栏**：输入网址 / 搜索词自动识别（非网址走百度搜索，与 Webplus 默认引擎一致）
- **100% 汉化**：全部界面文案 + 系统组件中文本地化
- 前进 / 后退 / 刷新 / 首页 / 加载进度条
- JS Bridge 通道（Web→App）：`ping`、`getAppInfo` 探活
- http / https 站点加载（ATS 已配置）

M3 规划：离线完整保存、翻译三层降级（在线 API→本地词库→原生翻译）、缓存管理、广告拦截（WKContentRuleList）、无痕模式、设置页。

## 目录结构

```
lib/
├── main.dart                        # 入口
├── app.dart                         # 应用根组件 / 主题
├── core/
│   ├── config/app_config.dart       # 首页、搜索引擎、UA、默认书签
│   └── bridge/
│       ├── bridge_message.dart      # 统一消息协议（JSON）
│       └── js_bridge.dart           # JS Bridge：Web→App / App→Web / 动作注册表
├── features/browser/
│   ├── browser_screen.dart          # 主界面
│   ├── webview_page.dart            # WebView 容器（加载/进度/历史/桥注入）
│   └── widgets/                     # 地址栏 / 进度条 / 工具栏
└── native/
    └── native_bridge.dart           # MethodChannel 占位（M2 接入原生能力）
```

## JS Bridge 协议

```
Web → App:  window.__NEWWEB_BRIDGE__.postMessage({id, action, payload})
App → Web:  window.__NEWWEB_NATIVE__(响应)   （页面侧需实现接收函数）
```

请求示例：`{"id":"1","action":"ping","payload":{}}` → 响应 `{"id":"1","ok":true,"data":"pong"}`。

新增动作：在 `JsBridge` 构造中 `register(action, handler)` 即可。

## 云端构建（推荐，无需本地 macOS）

推送到 GitHub 后，`Build iOS IPA` 工作流自动构建（macOS runner + Flutter 3.47.2 + Xcode）。

- **无签名模式**（默认）：产物可用 TrollStore / AltStore / Sideloadly / 爱思助手侧载
- **签名模式**：在仓库 **Settings → Secrets and variables → Actions** 配置以下 Secret 后自动启用：

| Secret | 内容 |
|---|---|
| `IOS_CERTIFICATE` | 你的 .p12 证书 base64 |
| `IOS_CERTIFICATE_PWD` | 证书密码 |
| `IOS_PROVISION_PROFILE` | .mobileprovision 描述文件 base64 |
| `KEYCHAIN_PASSWORD` | 任意临时钥匙串密码 |

base64 生成（macOS）：`base64 -i certificate.p12 | pbcopy`

> 证书 / 描述文件的 Bundle ID 必须与项目一致，当前为 `com.newweb.newweb`；
> 如需更改，修改 `ios/Runner.xcodeproj` 中的 `PRODUCT_BUNDLE_IDENTIFIER` 与工作流 `BUNDLE_ID`。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
# 构建需 macOS + Xcode：
cd ios && pod install
flutter build ios --release --no-codesign   # 无签名
```

## 版本管理

- **版本规则**：每次更新 `pubspec.yaml` 中 `version` 的版本号 +0.01（如 `1.0.0+1` → `1.0.1+1`，构建号保持不变）
- 应用名：`ios/Runner/Info.plist` 中 `CFBundleDisplayName` = 未来浏览器
- 打包模式：默认无签名 IPA（TrollStore 侧载）；配置证书 Secrets 后自动切换签名模式
