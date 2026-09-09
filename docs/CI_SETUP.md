# 未来浏览器 CI/CD 环境配置手册

## 仓库目录结构

```
newWeb/
├── .github/
│   └── workflows/
│       ├── build.yml          # 生产构建流水线（main 分支触发）
│       └── pr-check.yml       # PR 代码质量门禁（PR/非main分支触发）
├── scripts/
│   ├── version_bump.sh        # 版本解析+进位计算+安全写入
│   ├── version_bump_test.sh   # 版本进位单元测试（20组用例）
│   ├── update_readme.sh       # README 顶部更新日志插入
│   └── generate_metadata.sh   # 制品元数据 JSON + SHA256 生成
├── docs/
│   ├── CI_SETUP.md            # 本文件：环境配置手册
│   ├── CI_OPERATIONS.md       # 流水线运维&故障排查
│   └── ARTIFACT_GUIDE.md      # 制品说明文档
├── lib/                       # Flutter 源码（100% 中文汉化）
├── ios/                       # iOS 原生工程
├── pubspec.yaml               # 版本号唯一来源
└── README.md                  # 更新日志（CI 自动维护）
```

## GITHUB_TOKEN 权限说明

本流水线使用 GitHub 自动生成的 `GITHUB_TOKEN`，无需手动配置 Secrets。

### 所需权限

| 权限 | 用途 | 工作流 |
|------|------|--------|
| `contents: write` | 提交版本变更、推送 README 更新、创建 Release Tag | build.yml |
| `contents: read` | 检出代码 | pr-check.yml |

### 权限验证

在仓库 `Settings → Actions → General → Workflow permissions` 中，确保选择：
- ✅ **Read and write permissions**
- ✅ **Allow GitHub Actions to create and approve pull requests**

### 无需配置的 Secrets

本项目采用**无签名构建**模式，以下 Secrets **均不需要**：
- ❌ `IOS_CERTIFICATE`（签名证书）
- ❌ `IOS_CERTIFICATE_PWD`（证书密码）
- ❌ `IOS_PROVISION_PROFILE`（描述文件）
- ❌ `KEYCHAIN_PASSWORD`（钥匙串密码）

签名操作由用户在本地使用**全能签**完成。

## 分支策略

| 分支 | 触发流水线 | 行为 |
|------|-----------|------|
| `main` | build.yml | 完整生产流水线：版本递增 → 构建 → Draft Release |
| PR 到 main | pr-check.yml | 静态检查 + 编译校验，禁止版本/Release 操作 |
| 其他分支 | pr-check.yml | 静态检查 + 编译校验 |

## 版本管理规范

### 版本号来源

版本号唯一存储在 `pubspec.yaml` 的 `version` 字段：
```yaml
version: 1.1.0+1
```
格式：`主版本.次版本.补丁号+构建号`

### 自动进位规则

| 当前版本 | 递增后 | 说明 |
|---------|--------|------|
| 1.0.0 | 1.0.1 | 补丁 +1 |
| 1.0.8 | 1.0.9 | 补丁 +1 |
| 1.0.9 | 1.1.0 | 补丁满 9，次版本 +1 |
| 1.8.9 | 1.9.0 | 补丁满 9，次版本 +1 |
| 1.9.9 | 2.0.0 | 次版本满 9，主版本 +1 |
| 1.0.47 | 1.1.0 | 历史遗留补丁 >9，自动进位 |

### 版本递增触发时机

版本递增**仅在 main 分支推送时**由 CI 自动执行，禁止手动修改版本号。

## 首次部署检查清单

1. ✅ 仓库 `Settings → Actions → Workflow permissions` 设置为 Read and write
2. ✅ `scripts/` 目录下所有 `.sh` 文件有执行权限（`chmod +x scripts/*.sh`）
3. ✅ `pubspec.yaml` 中版本号为三段纯数字格式
4. ✅ 仓库为公开仓库（macOS Runner 免费额度无限）
5. ✅ 无需配置任何签名相关 Secrets

## 联系与支持

- 构建日志：`Actions → 未来浏览器生产构建`
- 制品下载：`Releases → Draft 草稿 → 附件`
- 版本历史：`README.md → 更新日志`
