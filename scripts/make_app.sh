#!/bin/bash
# 把 SwiftPM 产物打包成可双击运行的 .app（ad-hoc 签名，仅本机使用）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/lindongdao.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/lindongdao "$APP/Contents/MacOS/lindongdao"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "✅ 已生成 ${APP}（可拖到 /Applications）"
