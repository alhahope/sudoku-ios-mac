#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.app-build"
MODULE_CACHE="$ROOT/.clang-cache"
HOME_CACHE="$ROOT/.build-home"
XDG_CACHE="$ROOT/.build-cache"
APP_NAME="SudokuDesktopApp"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE" "$HOME_CACHE" "$XDG_CACHE" "$MACOS_DIR" "$RESOURCES_DIR"

export HOME="$HOME_CACHE"
export XDG_CACHE_HOME="$XDG_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"

swiftc \
  -module-name SudokuCore \
  -emit-module \
  -emit-library \
  -parse-as-library \
  "$ROOT"/Sources/SudokuCore/*.swift \
  -o "$BUILD_DIR/libSudokuCore.dylib" \
  -emit-module-path "$BUILD_DIR/SudokuCore.swiftmodule"

swiftc \
  -parse-as-library \
  -I "$BUILD_DIR" \
  -L "$BUILD_DIR" \
  -lSudokuCore \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  "$ROOT"/Sources/SudokuDesktopApp/*.swift \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>SudokuDesktopApp</string>
  <key>CFBundleIdentifier</key>
  <string>com.guokai.sudokudesktopapp</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SudokuDesktopApp</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$BUILD_DIR/libSudokuCore.dylib" "$MACOS_DIR/"
install_name_tool -change "$BUILD_DIR/libSudokuCore.dylib" "@executable_path/libSudokuCore.dylib" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

if [[ -f "$ROOT/debug-board.png" ]]; then
  cp "$ROOT/debug-board.png" "$RESOURCES_DIR/debug-board.png"
fi

echo "Built app bundle at: $APP_DIR"
