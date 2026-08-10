#!/bin/bash
#
# 构建并同时部署 AISudoLogic 到 macOS 与 iPhone 17 Pro Max 模拟器。
# 用法:./doc/sh/run_all.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

# 使用项目内固定 DerivedData 目录,确保每次构建产物是唯一的、最新的。
DERIVED_DATA="$PROJECT_DIR/.build"
BUILD_DIR="$DERIVED_DATA/Build/Products/Debug"
IOS_APP="$BUILD_DIR-iphonesimulator/AISudoLogic.app"
MAC_APP="$BUILD_DIR/AISudoLogic.app"

# 模拟器设备名与 Bundle ID
SIM_NAME="iPhone 17 Pro Max"
BUNDLE_ID="max.com.AISudoLogic"

echo "════════════════════════════════════════"
echo "  AISudoLogic · 双平台构建与部署"
echo "════════════════════════════════════════"

# ── 1. macOS 构建 ──────────────────────────
echo ""
echo "▶ [1/4] 构建 macOS 版本…"
xcodebuild -project AISudoLogic.xcodeproj -scheme AISudoLogic \
  -destination 'platform=macOS' -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" build 2>&1 | \
  grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" || true
if [ "${PIPESTATUS[0]}" -ne 0 ] || [ ! -d "$MAC_APP" ]; then
  echo "✗ macOS 构建失败"
  exit 1
fi
echo "✓ macOS 构建完成: $MAC_APP"

# ── 2. iOS 模拟器构建 ──────────────────────
echo ""
echo "▶ [2/4] 构建 iOS 模拟器版本…"
xcodebuild -project AISudoLogic.xcodeproj -scheme AISudoLogic \
  -destination "platform=iOS Simulator,name=$SIM_NAME" -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" build 2>&1 | \
  grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" || true
if [ "${PIPESTATUS[0]}" -ne 0 ] || [ ! -d "$IOS_APP" ]; then
  echo "✗ iOS 构建失败"
  exit 1
fi
echo "✓ iOS 构建完成: $IOS_APP"

# ── 3. 部署到 iOS 模拟器 ───────────────────
echo ""
echo "▶ [3/4] 部署到 $SIM_NAME 模拟器…"
# 找到设备 UDID(若未启动则先启动)
SIM_UDID="$(xcrun simctl list devices available | grep "$SIM_NAME" | grep -oE '[0-9A-F-]{36}' | head -1)"
if [ -z "$SIM_UDID" ]; then
  echo "✗ 未找到 $SIM_NAME 设备"
  exit 1
fi
# 确保模拟器已启动
if ! xcrun simctl list devices | grep "$SIM_UDID" | grep -q "Booted"; then
  echo "  启动模拟器…"
  xcrun simctl boot "$SIM_UDID" || true
  open -a Simulator
  sleep 3
fi
# 安装并启动(先卸载旧版本,确保是全新安装)
echo "  卸载旧版本…"
xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
echo "  安装新版本…"
xcrun simctl install "$SIM_UDID" "$IOS_APP"
echo "  启动中…"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
echo "✓ iOS 已在模拟器运行"

# ── 4. 启动 macOS 版本 ─────────────────────
echo ""
echo "▶ [4/4] 启动 macOS 版本…"
# 先退出旧实例,确保运行最新构建。
pkill -f "AISudoLogic.app/Contents/MacOS/AISudoLogic" 2>/dev/null || true
sleep 1
open "$MAC_APP"
echo "✓ macOS 已启动"

echo ""
echo "════════════════════════════════════════"
echo "  ✅ 双平台部署完成"
echo "    - macOS: $MAC_APP"
echo "    - $SIM_NAME: $IOS_APP"
echo "════════════════════════════════════════"
