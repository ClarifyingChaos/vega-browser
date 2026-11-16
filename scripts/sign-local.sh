#!/usr/bin/env bash
# Licensed under GPL-3.0. See LICENSE.
#
# Signs a local build with the same Apple Development certificate as releases, so the Keychain sees one app:
# its approvals (Always Allow) survive rebuilds and updates instead of being asked for again.
#
#   scripts/sign-local.sh build/Build/Products/Debug/Vega.app
set -euo pipefail
APP="${1:?usage: scripts/sign-local.sh path/to/Vega.app}"
cd "$(dirname "$0")/.."
ID=$(security find-identity -v -p codesigning | grep -m1 "Apple Development" | grep -oE '"[^"]+"' | tr -d '"' || true)
[[ -n "$ID" ]] || { echo "no Apple Development certificate in the login Keychain"; exit 1; }
codesign --force --deep --sign "$ID" --entitlements Nook/Nook-CI.entitlements "$APP"
codesign -dr - "$APP" 2>&1 | grep designated
