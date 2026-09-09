#!/usr/bin/env bash
# =============================================================================
# 脚本名称：version_bump.sh
# 脚本功能：三段式语义版本解析 + 自动进位计算 + 安全写入 pubspec.yaml
# 版本规则：主版本.次版本.补丁号，补丁位 0~9，满 9 自动进位
#   - 补丁 < 9：补丁 +1
#   - 补丁 == 9：补丁归零，次版本 +1
#   - 次版本 == 9 且补丁 == 9：次版本归零，主版本 +1
# 示例：1.0.9 → 1.1.0；1.9.9 → 2.0.0；2.3.9 → 2.4.0
# 说明：Flutter 项目版本由 pubspec.yaml 管理，构建时自动同步到 Info.plist
# 使用方式：./scripts/version_bump.sh [pubspec.yaml 路径]
# =============================================================================
set -euo pipefail

# ---------- 颜色输出（CI 环境自动降级为纯文本） ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  RESET=$(tput sgr0)
else
  RED="" GREEN="" YELLOW="" RESET=""
fi

log_info()  { echo "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo "${RED}[ERROR]${RESET} $*" >&2; }

# ---------- 参数校验 ----------
PUBSPEC_PATH="${1:-pubspec.yaml}"

if [ ! -f "$PUBSPEC_PATH" ]; then
  log_error "pubspec.yaml 不存在：$PUBSPEC_PATH"
  exit 1
fi

# ---------- 版本合法性校验函数 ----------
validate_version_format() {
  local ver="$1"
  if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "版本格式非法：$ver（必须为 主.次.补丁 三段纯数字）"
    exit 1
  fi
}

# ---------- 版本进位计算函数 ----------
bump_version() {
  local old_ver="$1"
  validate_version_format "$old_ver"

  IFS='.' read -r major minor patch <<< "$old_ver"

  # 补丁位 >= 9 时自动进位（兼容历史遗留的补丁位 > 9 情况）
  if [ "$patch" -ge 9 ]; then
    patch=0
    if [ "$minor" -ge 9 ]; then
      minor=0
      major=$((major + 1))
    else
      minor=$((minor + 1))
    fi
  else
    patch=$((patch + 1))
  fi

  echo "${major}.${minor}.${patch}"
}

# ---------- 从 pubspec.yaml 读取版本号 ----------
log_info "读取当前版本号..."
OLD_VERSION=$(grep '^version:' "$PUBSPEC_PATH" | head -1 | sed 's/version: *//' | sed 's/+.*//' | tr -d ' ')

if [ -z "$OLD_VERSION" ]; then
  log_error "从 pubspec.yaml 读取版本号失败"
  exit 1
fi

log_info "当前版本：$OLD_VERSION"
validate_version_format "$OLD_VERSION"

# 读取构建号（+后面的数字）
OLD_BUILD=$(grep '^version:' "$PUBSPEC_PATH" | head -1 | sed 's/.*+//' | tr -d ' ')
if [ -z "$OLD_BUILD" ] || [[ ! "$OLD_BUILD" =~ ^[0-9]+$ ]]; then
  OLD_BUILD=1
fi

# ---------- 计算新版本 ----------
NEW_VERSION=$(bump_version "$OLD_VERSION")
NEW_BUILD=$((OLD_BUILD + 1))
log_info "计算新版本：$OLD_VERSION+$OLD_BUILD → $NEW_VERSION+$NEW_BUILD"

# ---------- 防回退校验 ----------
IFS='.' read -r o_major o_minor o_patch <<< "$OLD_VERSION"
IFS='.' read -r n_major n_minor n_patch <<< "$NEW_VERSION"
if [ "$n_major" -lt "$o_major" ] || \
   { [ "$n_major" -eq "$o_major" ] && [ "$n_minor" -lt "$o_minor" ]; } || \
   { [ "$n_major" -eq "$o_major" ] && [ "$n_minor" -eq "$o_minor" ] && [ "$n_patch" -le "$o_patch" ]; }; then
  log_error "版本回退检测：新版本 $NEW_VERSION 不大于旧版本 $OLD_VERSION，终止"
  exit 1
fi

# ---------- 安全写入 pubspec.yaml ----------
log_info "写入新版本到 pubspec.yaml..."
# 使用 sed 精确替换 version 行
sed -i.bak "s/^version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" "$PUBSPEC_PATH"
rm -f "${PUBSPEC_PATH}.bak"

# 回读验证
VERIFY=$(grep '^version:' "$PUBSPEC_PATH" | head -1 | sed 's/version: *//' | sed 's/+.*//' | tr -d ' ')
if [ "$VERIFY" != "$NEW_VERSION" ]; then
  log_error "写入验证失败：期望 $NEW_VERSION，实际 $VERIFY"
  exit 1
fi

log_info "版本递增成功：$OLD_VERSION → $NEW_VERSION"
# 输出供 CI 后续步骤捕获
echo "NEW_VERSION=$NEW_VERSION"
echo "OLD_VERSION=$OLD_VERSION"
echo "NEW_BUILD=$NEW_BUILD"
