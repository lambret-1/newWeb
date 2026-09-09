#!/usr/bin/env bash
# =============================================================================
# 脚本名称：generate_metadata.sh
# 脚本功能：生成制品元数据 JSON 文件，用于离线校验与归档溯源
# 元数据字段：版本号、Git 短 Commit 哈希、构建时间、文件 SHA256、文件名、构建耗时
# 使用方式：./scripts/generate_metadata.sh <版本号> <commit短哈希> <构建时间> <文件路径> <构建耗时(秒)>
# =============================================================================
set -euo pipefail

# ---------- 参数校验 ----------
if [ $# -lt 5 ]; then
  echo "[ERROR] 参数不足，用法：$0 <版本号> <commit短哈希> <构建时间> <文件路径> <构建耗时(秒)>"
  exit 1
fi

VERSION="$1"
COMMIT_HASH="$2"
BUILD_TIME="$3"
FILE_PATH="$4"
BUILD_DURATION="$5"

if [ ! -f "$FILE_PATH" ]; then
  echo "[ERROR] 制品文件不存在：$FILE_PATH"
  exit 1
fi

# ---------- 计算 SHA256 ----------
FILE_NAME=$(basename "$FILE_PATH")
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")

# macOS 用 shasum，Linux 用 sha256sum
if command -v shasum >/dev/null 2>&1; then
  SHA256=$(shasum -a 256 "$FILE_PATH" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256=$(sha256sum "$FILE_PATH" | awk '{print $1}')
else
  echo "[ERROR] 未找到 SHA256 计算工具"
  exit 1
fi

# ---------- 生成 JSON ----------
OUTPUT_FILE="${FILE_PATH%.ipa}-metadata.json"

cat > "$OUTPUT_FILE" << EOF
{
  "app_name": "未来浏览器",
  "bundle_id": "com.newweb.newweb",
  "version": "${VERSION}",
  "git_commit": "${COMMIT_HASH}",
  "build_time": "${BUILD_TIME}",
  "build_duration_seconds": ${BUILD_DURATION},
  "file_name": "${FILE_NAME}",
  "file_size_bytes": ${FILE_SIZE},
  "sha256": "${SHA256}",
  "signing_mode": "unsigned",
  "target_platform": "iOS",
  "minimum_os_version": "15.0"
}
EOF

echo "[INFO] 制品元数据已生成：$OUTPUT_FILE"
echo "[INFO] SHA256: $SHA256"
# 输出 SHA256 供 CI 后续步骤捕获
echo "SHA256=$SHA256"
echo "METADATA_FILE=$OUTPUT_FILE"
