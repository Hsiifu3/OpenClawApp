#!/bin/bash
set -euo pipefail

APP_NAME="OpenClaw"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🔨 Building ${APP_NAME}..."
swift build -c release

echo "📦 Creating ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/"

# Copy Info.plist
cp Info.plist "${CONTENTS}/"

# Ad-hoc codesign (required for Apple Silicon)
echo "🔏 Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ ${APP_BUNDLE} built successfully!"
echo "   Run with: open ${APP_BUNDLE}"
