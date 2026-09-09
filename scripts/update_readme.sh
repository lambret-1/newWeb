#!/usr/bin/env bash
# =============================================================================
# 脚本名称：update_readme.sh
# 脚本功能：在 README.md 顶部「更新日志」标题下插入新版结构化日志
#           并自动只保留最后三个版本的日志
# 日志内容：版本号、Git 短 Commit 哈希、构建时间、IPA SHA256 摘要
# 使用方式：./scripts/update_readme.sh <版本号> <commit短哈希> <构建时间> <SHA256> [更新摘要]
# =============================================================================
set -euo pipefail

# ---------- 参数校验 ----------
if [ $# -lt 4 ]; then
  echo "[ERROR] 参数不足，用法：$0 <版本号> <commit短哈希> <构建时间> <SHA256> [更新摘要]"
  exit 1
fi

VERSION="$1"
COMMIT_HASH="$2"
BUILD_TIME="$3"
SHA256="$4"
UPDATE_SUMMARY="${5:-生产构建发布}"

README_PATH="README.md"
MAX_VERSIONS=3

if [ ! -f "$README_PATH" ]; then
  echo "[ERROR] README.md 不存在"
  exit 1
fi

# ---------- 构造新日志条目 ----------
LOG_ENTRY="### v${VERSION}（最新）
- **版本**：v${VERSION}
- **构建 Commit**：\`${COMMIT_HASH}\`
- **构建时间**：${BUILD_TIME}
- **IPA SHA256**：\`${SHA256}\`
"

# ---------- 定位插入点：「## 更新日志」标题下 ----------
if grep -q "^## 更新日志" "$README_PATH"; then
  LINE_NUM=$(grep -n "^## 更新日志" "$README_PATH" | head -1 | cut -d: -f1)
  # 在更新日志标题后插入新条目
  {
    head -n "$LINE_NUM" "$README_PATH"
    echo ""
    echo "$LOG_ENTRY"
    echo ""
    tail -n +$((LINE_NUM + 1)) "$README_PATH"
  } > "${README_PATH}.tmp"
  mv "${README_PATH}.tmp" "$README_PATH"
else
  echo "## 更新日志" >> "$README_PATH"
  echo "" >> "$README_PATH"
  echo "$LOG_ENTRY" >> "$README_PATH"
fi

# ---------- 只保留最后三个版本 ----------
# 找到所有 "### v" 行，超过 MAX_VERSIONS 的部分（从第四个开始）删除
awk -v max="$MAX_VERSIONS" '
  /^### v/ { count++ }
  {
    if (count <= max) {
      print
    }
  }
' "$README_PATH" > "${README_PATH}.tmp"
mv "${README_PATH}.tmp" "$README_PATH"

# 清理多余空行（连续多个空行压缩为一个）
awk 'NF { blank=0; print } !NF { if (!blank) { print; blank=1 } }' "$README_PATH" > "${README_PATH}.tmp"
mv "${README_PATH}.tmp" "$README_PATH"

echo "[INFO] README 更新日志已插入：v${VERSION}（仅保留最后 ${MAX_VERSIONS} 个版本）"
