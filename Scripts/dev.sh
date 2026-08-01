#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LazyDisk"
APP_PATH="$ROOT/dist/${APP_NAME}.app"

cd "$ROOT"

# Stop any running instance
pkill -x "$APP_NAME" 2>/dev/null || true

echo "Building..."
swift build

echo "Packaging app bundle..."
bash "$ROOT/Scripts/build-app.sh" >/dev/null

echo "Launching $APP_NAME..."
open "$APP_PATH"
