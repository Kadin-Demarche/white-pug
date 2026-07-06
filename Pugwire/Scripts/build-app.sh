#!/usr/bin/env bash
set -euo pipefail

# Builds dist/Pugwire.app from the Swift package. Run this on macOS with
# Xcode's command line tools installed (no full Xcode/.xcodeproj needed):
#   xcode-select --install

cd "$(dirname "$0")/.."

APP_NAME="Pugwire"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling ${APP_DIR}"
rm -rf "${DIST_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

echo "==> Ad-hoc signing (local use only, not notarized)"
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Done: ${APP_DIR}"
echo ""
echo "Move it to /Applications, then on first launch right-click the app"
echo "and choose Open (Gatekeeper will otherwise block this unsigned,"
echo "un-notarized local build with an 'unidentified developer' warning)."
