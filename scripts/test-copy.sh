#!/usr/bin/env bash
# Licensed under GPL-3.0. See LICENSE.
#
# An isolated copy of a Debug build for testing, beside the real Vega: its own bundle id, data and Keychain items.
#
#   scripts/test-copy.sh start [path/to/Vega.app]   copy, sign ad hoc, launch as "Vega Test"
#   scripts/test-copy.sh stop                        quit it and delete everything it wrote
set -euo pipefail
ID="com.vega.uitest"
PREFIX="$ID.kc"
DIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)/vega-test-copy"
MATCH="vega-test-copy/Vega Test.app/Contents/MacOS/"
cd "$(dirname "$0")/.."

case "${1:-}" in
start)
  SRC="${2:-build/Build/Products/Debug/Vega.app}"
  [[ -d "$SRC" ]] || { echo "no build at $SRC"; exit 1; }
  pgrep -f "$MATCH" >/dev/null && { echo "a test copy is already running; run stop first"; exit 1; }
  rm -rf "$DIR" && mkdir -p "$DIR"
  cp -R "$SRC" "$DIR/Vega Test.app"
  PLIST="$DIR/Vega Test.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ID" -c "Set :CFBundleName Vega Test" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Vega Test" "$PLIST" 2>/dev/null || true
  codesign --force --deep --sign - --entitlements Nook/Nook-CI.entitlements "$DIR/Vega Test.app" 2>/dev/null
  defaults write "$ID" fork.keychain.testPrefix -string "$PREFIX"
  defaults write "$ID" settings.didFinishOnboarding -bool true
  defaults write "$ID" fork.tour.seen -bool true
  defaults write "$ID" skipLegacyMigration -bool true
  # Fail closed: never launch unless the copy is set to its own Keychain items (the app also isolates itself).
  [[ "$(defaults read "$ID" fork.keychain.testPrefix 2>/dev/null)" == "$PREFIX" ]] || { echo "test prefix not set; not launching"; exit 1; }
  open -n "$DIR/Vega Test.app"
  echo "started: $DIR/Vega Test.app ($ID, Keychain prefix $PREFIX)"
  ;;
stop)
  pkill -f "$MATCH" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$MATCH" >/dev/null || break; sleep 0.5; done
  pgrep -f "$MATCH" >/dev/null && { echo "the test copy did not quit"; exit 1; }
  defaults delete "$ID" 2>/dev/null || true
  rm -rf "$DIR" ~/Library/Preferences/"$ID".plist
  for d in "Application Support" Caches WebKit HTTPStorages "Saved Application State"; do rm -rf ~/Library/"$d"/"$ID"*; done
  # The copy's own Keychain items, and nothing else: only services that start with its prefix.
  security dump-keychain 2>/dev/null | sed -n 's/.*"svce"<blob>="\('"$PREFIX"'[^"]*\)".*/\1/p' | sort -u | while read -r svc; do
    while security delete-generic-password -s "$svc" >/dev/null 2>&1; do :; done
  done
  echo "stopped and cleaned: $ID"
  ;;
*) echo "usage: scripts/test-copy.sh start [app] | stop"; exit 1 ;;
esac
