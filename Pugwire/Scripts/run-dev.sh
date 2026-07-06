#!/usr/bin/env bash
set -euo pipefail

# Runs Pugwire directly via `swift run` for local development.
#
# Note: launch-at-login and full Gatekeeper-free launching only work from
# the assembled .app bundle (see build-app.sh) since they depend on a
# stable bundle identifier and LSUIElement from Info.plist. A dock icon
# may briefly flash when running this way; that's expected in dev mode.

cd "$(dirname "$0")/.."
swift run
