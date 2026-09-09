#!/usr/bin/env bash
# =============================================================================
# 脚本名称：version_bump_test.sh
# 脚本功能：版本进位逻辑单元测试，覆盖边界案例与异常输入
# 测试对象：version_bump.sh 中的 bump_version 函数逻辑
# 使用方式：./scripts/version_bump_test.sh
# 退出码：0 = 全部通过，1 = 存在失败用例
# =============================================================================
set -euo pipefail

PASS=0
FAIL=0

# ---------- 颜色输出 ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  GREEN=$(tput setaf 2)
  RED=$(tput setaf 1)
  RESET=$(tput sgr0)
else
  GREEN="" RED="" RESET=""
fi

# ---------- 内联版本进位函数（与 version_bump.sh 保持一致） ----------
bump_version() {
  local old_ver="$1"
  if [[ ! "$old_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "INVALID_FORMAT"
    return 0
  fi
  IFS='.' read -r major minor patch <<< "$old_ver"
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

# ---------- 测试断言函数 ----------
assert_eq() {
  local test_name="$1"
  local input="$2"
  local expected="$3"
  local actual
  actual=$(bump_version "$input")

  if [ "$actual" == "$expected" ]; then
    echo "${GREEN}[PASS]${RESET} $test_name: $input → $actual"
    PASS=$((PASS + 1))
  else
    echo "${RED}[FAIL]${RESET} $test_name: $input → 期望 $expected，实际 $actual"
    FAIL=$((FAIL + 1))
  fi
}

# =============================================================================
# 测试用例
# =============================================================================

echo "========== 版本进位单元测试 =========="
echo ""

# --- 正常递增（补丁位 0~8） ---
assert_eq "补丁位0递增"    "1.0.0" "1.0.1"
assert_eq "补丁位1递增"    "1.0.1" "1.0.2"
assert_eq "补丁位8递增"    "1.0.8" "1.0.9"
assert_eq "非零次版本递增" "2.3.4" "2.3.5"
assert_eq "大版本号递增"   "10.20.5" "10.20.6"

# --- 补丁位进位（补丁 == 9） ---
assert_eq "补丁9进位到次版本"     "1.0.9" "1.1.0"
assert_eq "补丁9进位非零次版本"   "2.3.9" "2.4.0"
assert_eq "补丁9进位次版本8"      "1.8.9" "1.9.0"

# --- 次版本进位（次版本 == 9 且补丁 == 9） ---
assert_eq "次版本9补丁9进位主版本" "1.9.9" "2.0.0"
assert_eq "大版本次版本9进位"      "5.9.9" "6.0.0"

# --- 历史遗留兼容（补丁位 > 9，自动进位） ---
assert_eq "补丁位47自动进位" "1.0.47" "1.1.0"
assert_eq "补丁位10自动进位" "1.0.10" "1.1.0"
assert_eq "补丁位99自动进位" "1.0.99" "1.1.0"

# --- 多级进位（次版本 > 9 兼容） ---
assert_eq "次版本10补丁9进位" "1.10.9" "2.0.0"

# --- 非法格式 ---
assert_eq "非三段式版本"     "1.0"    "INVALID_FORMAT"
assert_eq "四段式版本"       "1.0.0.0" "INVALID_FORMAT"
assert_eq "含字母版本"       "1.0.a"  "INVALID_FORMAT"
assert_eq "空字符串"         ""       "INVALID_FORMAT"
assert_eq "纯数字无点"       "100"    "INVALID_FORMAT"
assert_eq "负号版本"         "1.-1.0" "INVALID_FORMAT"

# =============================================================================
# 测试结果汇总
# =============================================================================
echo ""
echo "========== 测试结果汇总 =========="
echo "通过：$PASS"
echo "失败：$FAIL"
echo "总计：$((PASS + FAIL))"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "${RED}[RESULT] 存在失败用例，终止流水线${RESET}"
  exit 1
else
  echo ""
  echo "${GREEN}[RESULT] 全部通过${RESET}"
  exit 0
fi
