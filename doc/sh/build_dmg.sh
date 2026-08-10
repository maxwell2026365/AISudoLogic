#!/bin/bash
#
# build_dmg.sh — 将 AISudoLogic 构建为可直接安装运行的 DMG 安装包。
#
# 功能:
#   1. 用 Release 配置编译 macOS 版本的 AISudoLogic.app
#   2. 制作 DMG 镜像,内含「AISudoLogic.app + Applications 快捷方式」
#      (用户拖拽 app 到 Applications 即可完成安装)
#   3. 产物输出到 doc/dist/ 分类目录
#
# 用法:
#   ./doc/sh/build_dmg.sh
#
# 可选环境变量:
#   CONFIGURATION=Release   构建配置(默认 Release)
#
# 依赖: Xcode 命令行工具(xcodebuild)、hdiutil(系统自带)
#
set -euo pipefail

# ── 路径配置 ────────────────────────────────
# 脚本所在目录的上级的上级 = 项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="$PROJECT_DIR/.build"                      # 固定 DerivedData,产物位置可预期
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/AISudoLogic.app"
DIST_DIR="$PROJECT_DIR/doc/dist"                        # 产物根目录
STAGE_DIR="$DIST_DIR/.stage"                            # 临时打包目录
DIST_DIRS=("macOS" "iOS" "Universal")                   # 版本目录下按平台分类

VERSION="$(xcodebuild -project AISudoLogic.xcodeproj -scheme AISudoLogic \
  -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}')"
VERSION="${VERSION:-1.0.0}"

# 版本目录名:直接使用 MARKETING_VERSION(如 1.0.0 → V1.0.0)。
VERSION_DIR_NAME="V$VERSION"

VERSION_DIR="$DIST_DIR/$VERSION_DIR_NAME"               # 版本目录
ARCH="$(uname -m)"                                       # arm64 / x86_64
DMG_NAME="AISudoLogic-${VERSION_DIR_NAME}-${ARCH}-macOS.dmg"
DMG_PATH="$VERSION_DIR/macOS/$DMG_NAME"
VOLUME_NAME="AISudoLogic"

# 确保产物目录结构存在
mkdir -p "$DIST_DIR"
for d in "${DIST_DIRS[@]}"; do
  mkdir -p "$VERSION_DIR/$d"
done

echo "════════════════════════════════════════"
echo "  AISudoLogic · DMG 打包"
echo "  版本: $VERSION (目录 $VERSION_DIR_NAME) · 架构: $ARCH · 配置: $CONFIGURATION"
echo "════════════════════════════════════════"

# ── 1. 构建 macOS Release ───────────────────
echo ""
echo "▶ [1/3] 构建 macOS $CONFIGURATION 版本…"
xcodebuild -project AISudoLogic.xcodeproj -scheme AISudoLogic \
  -destination 'platform=macOS' -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" build 2>&1 | \
  grep -E "BUILD SUCCEEDED|BUILD FAILED|error:|warning:" || true
if [ "${PIPESTATUS[0]}" -ne 0 ] || [ ! -d "$APP_PATH" ]; then
  echo "✗ macOS 构建失败"
  exit 1
fi
echo "✓ 构建完成: $APP_PATH"

# ── 2. 检查/清除旧 DMG ─────────────────────
if [ -f "$DMG_PATH" ]; then
  echo ""
  echo "▶ 移除旧 DMG: $DMG_PATH"
  rm -f "$DMG_PATH"
fi

# ── 3. 制作 DMG ────────────────────────────
echo ""
echo "▶ [2/3] 制作 DMG 安装包…"

# 清理临时目录
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

# 准备 DMG 内容:app + Applications 快捷方式(拖拽安装)
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# 用 hdiutil 创建只读 DMG
# -volname: 挂载卷名; -srcfolder: 打包源目录; -ov: 覆盖; -format UDZO: 压缩
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE_DIR" \
  -ov -format UDZO "$DMG_PATH" >/dev/null

# 清理临时目录
rm -rf "$STAGE_DIR"

if [ ! -f "$DMG_PATH" ]; then
  echo "✗ DMG 创建失败"
  exit 1
fi

echo "✓ DMG 生成完成"

# ── 完成 ────────────────────────────────────
echo ""
echo "▶ [3/3] 校验与清理…"
# 校验 DMG 完整性
hdiutil verify "$DMG_PATH" >/dev/null 2>&1 && echo "✓ DMG 校验通过"

echo ""
echo "════════════════════════════════════════"
echo "  ✅ DMG 打包完成"
echo "    产物: $DMG_PATH"
echo ""
echo "  使用方式:"
echo "    1. 双击打开 DMG"
echo "    2. 将 AISudoLogic.app 拖入 Applications 文件夹"
echo "    3. 从启动台/应用程序中打开 AISudoLogic"
echo "════════════════════════════════════════"
