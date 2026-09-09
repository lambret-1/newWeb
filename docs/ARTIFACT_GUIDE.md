# 未来浏览器制品说明文档

## 制品清单

每次生产构建会生成以下制品，同时上传至 GitHub Actions Artifacts 和 Draft Release：

| 制品 | 文件名 | 说明 |
|------|--------|------|
| 未签名 IPA | `NewWeb.ipa` | 供全能签重签名安装 |
| 制品元数据 | `NewWeb-metadata.json` | 版本、哈希、构建信息 |

## SHA256 校验使用说明

### 为什么需要校验

确保下载的 IPA 文件完整、未被篡改、与 CI 构建产物一致。

### 校验方法

**macOS / Linux：**
```bash
shasum -a 256 NewWeb.ipa
```

**Windows（PowerShell）：**
```powershell
Get-FileHash NewWeb.ipa -Algorithm SHA256
```

### 校验值来源

SHA256 值可在以下位置获取：
1. Draft Release 正文的「IPA SHA256」字段
2. `NewWeb-metadata.json` 文件中的 `sha256` 字段
3. README.md 更新日志中的 SHA256 摘要

### 校验示例

```bash
# 计算哈希
$ shasum -a 256 NewWeb.ipa
a1b2c3d4e5f6...  NewWeb.ipa

# 与 Release 中的值对比，一致则文件完整
```

## 全能签导入 IPA 注意事项

### 前置条件

- 已安装**全能签**应用
- 有效的 Apple ID 或证书（全能签内配置）
- iOS 设备已开启开发者模式（iOS 16+）

### 导入步骤

1. 从 GitHub Draft Release 下载 `NewWeb.ipa`
2. 在全能签中选择「导入 IPA」
3. 选择下载的 `NewWeb.ipa` 文件
4. 配置签名证书（个人证书 / 企业证书）
5. 点击「开始签名」
6. 签名完成后选择「安装到设备」
7. 在设备上信任开发者证书

### 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 导入失败「IPA 格式错误」 | 文件下载不完整 | 重新下载，校验 SHA256 |
| 安装后闪退 | 证书无效或未信任 | 重新签名，在设置中信任证书 |
| 无法安装「不受信任」 | 未信任开发者 | 设置 → 通用 → VPN与设备管理 → 信任 |
| 全能签签名失败 | 证书过期 | 更新全能签中的证书 |

### TrollStore 安装（推荐）

如果设备支持 TrollStore（iOS 14-17 特定版本）：

1. 下载 `NewWeb.ipa`
2. 在 TrollStore 中选择「Install IPA」
3. 选择文件后自动安装
4. 无需重签名，永久有效

## 制品元数据 JSON 说明

### 文件结构

```json
{
  "app_name": "未来浏览器",
  "bundle_id": "com.newweb.newweb",
  "version": "1.1.0",
  "git_commit": "a1b2c3d",
  "build_time": "2026-09-09 12:00:00",
  "build_duration_seconds": 480,
  "file_name": "NewWeb.ipa",
  "file_size_bytes": 25165824,
  "sha256": "a1b2c3d4e5f6...",
  "signing_mode": "unsigned",
  "target_platform": "iOS",
  "minimum_os_version": "15.0"
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `app_name` | 应用显示名称 |
| `bundle_id` | 应用 Bundle Identifier |
| `version` | 语义化版本号 |
| `git_commit` | 构建对应的 Git 短哈希 |
| `build_time` | 构建完成时间（UTC+8） |
| `build_duration_seconds` | 构建总耗时（秒） |
| `file_name` | IPA 文件名 |
| `file_size_bytes` | IPA 文件大小（字节） |
| `sha256` | IPA 文件 SHA256 哈希 |
| `signing_mode` | 签名模式（固定为 unsigned） |
| `target_platform` | 目标平台（固定为 iOS） |
| `minimum_os_version` | 最低系统版本 |

### 元数据用途

- **离线校验**：无需访问 GitHub 即可验证制品完整性
- **归档溯源**：每个版本的构建信息永久保存
- **自动化脚本**：可被外部脚本解析，用于自动更新检测

## iOS 15+ 部署说明

### 系统要求

- **最低版本**：iOS 15.0
- **推荐版本**：iOS 16.0+
- **设备架构**：arm64（iPhone 6s 及以上）

### 功能兼容性

| 功能 | iOS 15 | iOS 16+ |
|------|--------|---------|
| WKWebView 核心 | ✅ | ✅ |
| 多标签快照 | ✅ | ✅ |
| 下拉刷新 | ✅ | ✅ |
| 手势灵敏度 | ✅ | ✅ |
| 密码本自动填充 | ✅ | ✅ |
| 网页截长图 | ✅ | ✅ |
| 网页导出 PDF | ✅ | ✅ |

### 已知限制

- iOS 15 上部分 CSS 特性可能存在差异
- 后台标签页存活时间受系统内存管理限制
- DNS 过滤功能需安装描述文件，iOS 15+ 均支持

## Draft Release 使用指引

### 什么是 Draft Release

Draft Release 是 GitHub 的草稿发布功能：
- **不会**自动通知关注者
- **不会**出现在仓库主页的 Releases 列表
- **只有**仓库协作者可以看到
- 需要人工点击「Publish release」才会正式发布

### 发布流程

1. CI 构建完成后，自动创建 Draft Release
2. 进入仓库 `Releases` 页面
3. 找到标题为「未来浏览器 vX.Y.Z」的草稿
4. 点击「Edit」检查内容
5. 确认无误后点击「Publish release」
6. 发布后所有用户可在 Releases 页面下载

### 回滚 Draft

如果发现问题：
1. 进入 Draft Release 编辑页面
2. 点击「Delete release」删除草稿
3. 修复代码后重新推送，CI 会创建新的 Draft

### 版本 Tag 管理

- 每个 Draft Release 对应一个 Git Tag（格式：`vX.Y.Z`）
- Tag 在创建 Release 时自动创建并推送
- 如果删除 Draft Release，Tag 也会被删除
- **禁止**手动创建与版本号重复的 Tag
