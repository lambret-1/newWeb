# 未来浏览器 — 轻量 iOS 浏览器（Flutter + WKWebView 混合开发）

Flutter 3.47.x + [webview_flutter](https://pub.dev/packages/webview_flutter) 4.14.x 构建的 iOS 浏览器（工程名 NewWeb）。
iOS 底层为系统 WKWebView（App Store 对浏览器的强制要求），Flutter 提供壳 UI 与业务逻辑，Swift 原生层提供下载、内容拦截、中文菜单等系统能力。

- **目标系统**：iOS 15.0+
- **包名**：com.newweb.newweb
- **应用名**：未来浏览器

## 功能特性

### 浏览核心
- **多标签页**：最多 8 个，网格切换 / 关闭 / 新建，后台标签保活
- **手势导航**：左边缘右滑返回、右边缘左滑前进（与页面滚动共存）
- **下拉刷新**、前进 / 后退 / 刷新 / 首页 / 加载进度条
- **地址栏**：网址 / 搜索词自动识别（非网址走所选搜索引擎，支持百度 / 必应 / Google）
- **无痕模式**：不记录历史；退出无痕时清空全部网站数据
- **100% 汉化**：全部界面文案 + 系统组件中文本地化 + 长按菜单中文化

### 网页翻译
- **整页翻译**：收集页面可见文本 → 翻译 → 按原文位置回填，可一键恢复原文
- **手动翻译**（长按菜单 / 更多菜单「翻译此页」）与**自动翻译**（自定义网址白名单，精确或子域匹配，加载完成后自动触发）
- **在线 / 离线双模式**：在线走 Google → MyMemory → 腾讯云三级降级；离线仅走内置本地词库
- 翻译模式可在设置页切换（自动 / 在线 / 离线）

### 下载管理
- 原生 URLSession 下载，支持**暂停 / 断点续传 / 取消**，落盘 Documents/Downloads，重名自动去重
- 网页内点击常见文件后缀链接（zip / apk / ipa / dmg / pdf 等）**自动接管下载**
- 下载管理页：进行中任务（进度条 / 暂停 / 续传 / 取消）+ 已完成列表（原生预览 / 分享 / 删除）
- **手动输入链接下载**兜底（无后缀 CDN 链接可用长按菜单「下载链接」或手动粘贴）

### 广告拦截（原生 WKContentRuleList）
七大模块：
1. **资源拦截 block**：80+ 广告域名黑名单（doubleclick、googlesyndication、google-analytics、facebook、umeng、cnzz、home.baidu、字节广告域等），正则 url-filter 匹配，原生编译注入
2. **DOM 元素隐藏 css-display-none**：CSS 选择器隐藏同域投放广告
3. **Cookie 与追踪拦截 block-cookies**：拦截 GA / FB Pixel 等追踪器
4. **弹窗拦截**：拦截 popup 类型请求 + JS window.open 守卫
5. **DNS 层过滤**：生成 AdGuard DNS 配置描述文件（设置页 → 安装 AdGuard DNS），系统级域名解析拦截
6. **阅读器模式**：内置正文提取（按 p 标签 / 文本长度打分，剔除广告与评论区），原生阅读页渲染，字号可调
7. **反广告检测对抗**：豁免站点白名单（ignore-previous-rules），命中站点跳过全部拦截，防止"请关闭广告拦截"提示

### 缓存管理（四级）
- **L1 网页缓存**：沙盒 Caches 与网络缓存（clearHttpCache）
- **L2 网络缓存**：WebView 磁盘缓存（diskCache）
- **L3 Cookie 与站点数据**：Cookie / localStorage / IndexedDB / WebSQL（显示记录数）
- **L4 全部数据**：网站数据 + 离线页面 + 历史记录一键清空
- 入口：更多菜单「缓存管理」或 设置 → 存储

### 其他
- 书签（默认书签 / 添加 / 删除，SQLite 存储）、历史记录（自动记录 / 相对时间 / 清空）
- 离线页面：整页保存（HTML + 内联 CSS/图片），离线可读
- 长按链接中文菜单：复制 / 翻译此页 / 下载链接
- JS Bridge 通道（Web→App / App→Web）

## 更新日志

### v1.0.9（最新）
- **快照修复**：页面加载完成后延迟 400ms 截图（等渲染稳定），标签切换页优先读取磁盘快照文件，App 重启后快照仍保留
- **标签切换页底部栏改版**：左下角「修改」+ 中间蓝色加号（新建空白标签）+ 右下角「完成」
- **修改子菜单**：「选择标签页」进入批量选择模式；「关闭所有标签页」二次确认后清空
- **批量选择模式**：左上角「全选/取消全选」、右上角「完成」；卡片右上角蓝色圆圈选择指示器（选中显示白色对勾）；选中卡片蓝色边框高光
- **批量操作栏**：选择模式底部显示「关闭 N 个」「添加 N 个书签」，未选择时灰色禁用
- 删除卡片内「当前」文字，当前激活标签改用蓝色边框标识（对齐 Chrome 风格）

### v1.0.8
- **LRU 标签内存回收**：同时最多保活 6 个最近使用的 WKWebView，超出的标签自动休眠释放内存；切回休眠标签时重建 WebView 并恢复页面
- **快照磁盘持久化**：页面加载完成时截图写入沙盒稳定路径（按标签 ID 命名），App 重启后标签网格仍可显示上次浏览快照；关闭标签同步删除快照
- **滚动位置保存恢复**：离开标签时保存页面滚动偏移，重建/重启后自动恢复浏览位置
- **底部工具栏改版**：中间主页图标替换为加号（新建空白标签页 about:blank）；多标签图标改为 Chrome 风格圆角方框 + 实时标签数量
- 无痕模式不生成快照、不保存会话、不保存滚动位置

### v1.0.7
- **修复标签快照不显示**：改为原生写 PNG 文件 + URL 匹配标签，绕过大消息传输限制；页面加载完成 / 切换标签时自动更新
- **标签会话持久化**：退出应用后标签（URL / 标题 / 激活项）自动保存，下次启动恢复；无痕模式不保存不恢复
- **广告拦截自定义规则**：设置 → 广告拦截 → 自定义规则（拦截域名 / 隐藏元素 / 豁免站点 / 高级 JSON），变更即时重新注入，无需发版
  - 域名输入自动清洗：粘贴 `https://www.example.com/path` 自动去掉 https:// 前缀与路径尾缀，自动匹配所有子域
  - 豁免白名单已收编至自定义规则页（设置页旧数据自动迁移）
- 长按中文菜单修复：WebView 无原生 uiDelegate 时菜单也生效

### v1.0.6
- **下载增加弹窗确认**：网页内下载链接自动接管、长按菜单「下载链接」均先弹确认框，确认后才开始下载
- **多标签浏览快照**：标签切换页每个标签卡片显示最后浏览快照（原生 WKWebView 截图，页面加载完成 / 切换标签时自动更新）
- **build.yml 全面汉化**：工作流名称、任务、步骤、注释全部改为中文

### v1.0.5
- **修复下载拉起**：网页内点击下载链接（zip/apk/ipa/dmg/pdf 等常见后缀）自动接管为原生下载，不再被 WebView 当普通页面打开
- 下载管理页新增**手动输入链接下载**兜底入口
- 更多菜单可滚动（修复「下载管理」「设置」被裁剪不可见）；新增「缓存管理」快捷入口

### v1.0.4
- 修复更多菜单内容超出屏幕被裁剪、无法滚动的问题
- 更多菜单新增「缓存管理」快捷入口

### v1.0.3（M4）
- 下载管理（断点续传 / 暂停 / 取消 / 已完成列表）
- 网页翻译重构：整页翻译，手动 + 自动白名单，在线 / 离线双模式
- 缓存管理升级为四级（L1~L4）
- 广告拦截升级为原生 WKContentRuleList 七大模块
- 长按菜单汉化（复制 / 翻译此页 / 下载链接）；删除与原生选中贴窗重叠的选中翻译

### v1.0.2（M3）
- 离线整页保存 / 翻译三层降级 / 缓存管理 / JS 广告拦截 / 无痕模式 / 设置页

### v1.0.1（M2）
- 多标签 / 手势导航 / 书签 / 历史记录 / 100% 汉化

### v1.0.0（M1）
- 项目骨架 / 浏览核心 / 下拉刷新 / JS Bridge

## 目录结构

```
lib/
├── main.dart                        # 入口
├── app.dart                         # 应用根组件 / 主题 / 启动初始化
├── core/
│   ├── config/app_config.dart       # 首页、搜索引擎、UA、默认书签
│   ├── db/database_helper.dart      # SQLite（书签 / 历史）
│   ├── bridge/                      # JS Bridge（js_bridge / web_injections）
│   └── services/                    # 设置 / 翻译 / 广告拦截 / 下载 / 离线
├── features/browser/
│   ├── browser_screen.dart          # 主界面（菜单入口）
│   ├── webview_page.dart            # WebView 容器（导航 / 翻译 / 阅读器）
│   ├── download_page.dart           # 下载管理
│   ├── cache_manager_page.dart      # 四级缓存
│   ├── reader_page.dart             # 阅读器模式
│   ├── settings_page.dart           # 设置
│   └── widgets/                     # 地址栏 / 进度条 / 工具栏 / 手势层
└── native/
    └── native_bridge.dart           # MethodChannel + EventChannel

ios/Runner/
├── NativeBridge.swift               # 原生桥（清数据 / 下载 / DNS / 内容拦截）
├── DownloadManager.swift            # URLSession 下载（断点续传）
├── ContentBlockerManager.swift      # WKContentRuleList 编译注入
├── WebViewDelegateWrapper.swift     # 中文长按菜单（WKUIDelegate 包装）
└── assets/adblock_rules.json        # 广告拦截规则（Dart 侧）
```

## 云端构建（推荐，无需本地 macOS）

推送到 GitHub 后，`Build iOS IPA` 工作流自动构建（macOS runner + Flutter 3.47.2 + Xcode）。

- **无签名模式**（默认）：产物 `NewWeb-unsigned-ipa`，用 TrollStore / AltStore / Sideloadly / 爱思助手侧载
- **签名模式**：在仓库 **Settings → Secrets and variables → Actions** 配置以下 Secret 后自动切换：

| Secret | 内容 |
|---|---|
| `IOS_CERTIFICATE` | 你的 .p12 证书 base64 |
| `IOS_CERTIFICATE_PWD` | 证书密码 |
| `IOS_PROVISION_PROFILE` | .mobileprovision 描述文件 base64 |
| `KEYCHAIN_PASSWORD` | 任意临时钥匙串密码 |

base64 生成（macOS）：`base64 -i certificate.p12 | pbcopy`

> 证书 / 描述文件的 Bundle ID 必须与项目一致（`com.newweb.newweb`）；
> 构建完成后在 Actions 页面下载对应版本 IPA 产物。

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

- **版本规则**：每次更新 `pubspec.yaml` 中 `version` 的版本号 +0.01（如 `1.0.4+1` → `1.0.5+1`），并同步本文件「更新日志」
- 应用名：`ios/Runner/Info.plist` 中 `CFBundleDisplayName` = 未来浏览器
- 打包模式：默认无签名 IPA（TrollStore 侧载）；配置证书 Secrets 后自动切换签名模式
