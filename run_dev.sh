#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/flutter_3.24.5/bin:$HOME/.cargo/bin:$PATH"
export VCPKG_ROOT="$HOME/vcpkg"

# Ensure service binary is copied into app bundle if built
if [ -f "$DIR/target/release/service" ]; then
  mkdir -p "$DIR/flutter/build/macos/Build/Products/Debug/RustDesk.app/Contents/MacOS"
  cp -f "$DIR/target/release/service" "$DIR/flutter/build/macos/Build/Products/Debug/RustDesk.app/Contents/MacOS/" 2>/dev/null || true
elif [ -f "$DIR/target/debug/service" ]; then
  mkdir -p "$DIR/flutter/build/macos/Build/Products/Debug/RustDesk.app/Contents/MacOS"
  cp -f "$DIR/target/debug/service" "$DIR/flutter/build/macos/Build/Products/Debug/RustDesk.app/Contents/MacOS/" 2>/dev/null || true
fi

cd "$DIR/flutter"
rm -rf build/native_assets build/macos/Build/Products/Debug/RustDesk.app/Contents/Frameworks/native_assets.json "$HOME"/Library/Developer/Xcode/DerivedData/Runner*/Build/Products/Debug/RustDesk.app/Contents/Frameworks/native_assets.json

flutter run -d macos "$@"
