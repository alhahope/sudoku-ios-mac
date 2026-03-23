#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/iOS/SudokuMobileApp.xcodeproj"
BUILD_DIR="$ROOT/iOS/build"

mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme SudokuMobileApp \
  -configuration Debug \
  -sdk iphonesimulator \
  SYMROOT="$BUILD_DIR" \
  OBJROOT="$ROOT/iOS/obj" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Built iOS simulator app at: $BUILD_DIR/Debug-iphonesimulator/SudokuMobileApp.app"
