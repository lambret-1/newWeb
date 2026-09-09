# 未来浏览器 CI/CD 运维与故障排查手册

## 流水线架构总览

```
main 分支推送
    │
    ▼
┌─────────────────────────┐
│  Job 1: 版本递增与静态检查  │
│  - 版本单元测试（20组）    │
│  - 版本自动递增           │
│  - 提交版本变更           │
│  - Flutter 静态分析       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Job 2: iOS 无签名构建     │
│  - Flutter 编译          │
│  - xcodebuild 无签名构建   │
│  - ad-hoc 临时签名        │
│  - IPA 打包              │
│  - SHA256 + 元数据 JSON   │
│  - Artifacts 上传        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Job 3: Draft Release     │
│  - Tag 唯一性校验         │
│  - README 更新日志        │
│  - 创建 Draft Release    │
│  - 上传 IPA + 元数据      │
└─────────────────────────┘
```

## 版本进位逻辑调试

### 本地运行单元测试

```bash
# 运行全部 20 组测试用例
bash scripts/version_bump_test.sh

# 预期输出：通过 20，失败 0
```

### 本地测试版本递增（不修改文件）

```bash
# 手动测试进位逻辑（使用内联函数）
source <(sed -n '/^bump_version/,/^}/p' scripts/version_bump.sh)
bump_version "1.0.9"   # 输出 1.1.0
bump_version "1.9.9"   # 输出 2.0.0
bump_version "2.3.4"   # 输出 2.3.5
```

### 实际执行版本递增（会修改 pubspec.yaml）

```bash
bash scripts/version_bump.sh
# 输出：NEW_VERSION=1.1.0, OLD_VERSION=1.0.47
```

### 版本进位边界案例

| 输入 | 输出 | 说明 |
|------|------|------|
| 1.0.0 | 1.0.1 | 正常递增 |
| 1.0.9 | 1.1.0 | 补丁进位 |
| 1.9.9 | 2.0.0 | 次版本进位 |
| 9.9.9 | 10.0.0 | 主版本进位 |
| 1.0.47 | 1.1.0 | 历史遗留兼容 |

## 常见故障排查

### 1. 版本单元测试失败

**现象**：Job 1 在「版本进位单元测试」步骤失败

**排查步骤**：
1. 查看失败的具体用例
2. 检查 `scripts/version_bump.sh` 中 `bump_version` 函数逻辑
3. 本地运行 `bash scripts/version_bump_test.sh` 复现
4. 修复后重新推送

**常见原因**：
- 修改了进位逻辑但未同步更新测试用例
- Shell 语法错误（如未加引号导致的分词问题）

### 2. 版本递增后 CI 重复触发

**现象**：CI 构建完成后又触发一次新的构建

**原因**：CI 提交版本变更后推送到 main，触发了新的 push 事件

**解决方案**：
- 当前设计中，版本递增提交会触发新构建，但第二次构建时版本已递增，不会重复递增
- 如需避免，可在提交信息中加入 `[skip ci]`，但当前设计选择不跳过以确保版本一致性

### 3. Flutter 静态分析失败

**现象**：Job 1 在「Flutter 静态分析」步骤失败

**排查步骤**：
1. 本地运行 `flutter analyze lib/` 查看错误详情
2. 修复所有 `error` 级别的问题
3. 警告数量超过 20 也会失败，需修复或调整阈值

**调整警告阈值**：修改 `.github/workflows/pr-check.yml` 中的 `WARNING_THRESHOLD` 环境变量

### 4. iOS 编译失败

**现象**：Job 2 在「编译应用」步骤失败

**常见原因与解决方案**：

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `requires a selected Development Team` | Flutter 构建尝试签名 | 确认使用 `--no-codesign --config-only` + xcodebuild 直接构建 |
| `Pod install` 失败 | 依赖源问题 | 流水线已加 `--repo-update \|\| pod install` 兜底 |
| `Runner.app not found` | 构建路径变更 | 检查 `build/ios/DerivedData/Build/Products/Release-iphoneos/` |
| Xcode 版本不兼容 | Runner 环境更新 | 检查 `FLUTTER_VERSION` 与 Xcode 兼容性 |

### 5. Release 创建失败

**现象**：Job 3 在「创建 Draft Release」步骤失败

**常见原因**：

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `Tag already exists` | 版本号重复 | 检查 pubspec.yaml 版本号，确保版本递增正确 |
| `Permission denied` | GITHUB_TOKEN 权限不足 | 仓库 Settings → Actions → Workflow permissions 设为 Read and write |
| `Artifact not found` | 制品下载失败 | 检查 Job 2 的 Artifacts 上传是否成功 |

### 6. IPA 无法安装

**现象**：下载 IPA 后无法安装到设备

**排查步骤**：
1. 确认使用**全能签**或 TrollStore 进行重签名
2. 无签名 IPA 不能直接安装，必须重签名
3. 检查 IPA 包结构：`unzip -l NewWeb.ipa | grep Payload`
4. 验证 SHA256：`shasum -a 256 NewWeb.ipa`

### 7. 构建超时

**现象**：流水线在 45 分钟内未完成

**优化措施**：
- 流水线已启用 Flutter 缓存和 CocoaPods 缓存
- 检查是否有大型资源文件导致编译缓慢
- 考虑拆分构建步骤

## 构建耗时参考

| 阶段 | 预计耗时 |
|------|---------|
| 版本递增 + 静态检查 | 2-3 分钟 |
| iOS 编译 | 5-8 分钟 |
| Draft Release | 1-2 分钟 |
| **总计** | **8-13 分钟** |

## 手动触发构建

1. 进入仓库 `Actions` 页面
2. 选择「未来浏览器生产构建」
3. 点击「Run workflow」
4. 选择 `main` 分支
5. 点击「Run workflow」

## 紧急回滚

如果新版本存在严重问题：

1. 在 `Releases` 页面删除 Draft Release（如果尚未发布）
2. 使用 `git revert` 回退问题提交
3. 推送回退后的代码，CI 会自动构建新版本
4. 注意：版本号只会递增，不会回退，回退后的版本号会继续递增

## 运维监控建议

- 定期检查 `Actions` 页面构建状态
- 关注构建耗时趋势，异常增长需排查
- 定期清理旧的 Artifacts（流水线已设置 90 天自动清理）
- 每月验证一次 Draft Release 流程是否正常
