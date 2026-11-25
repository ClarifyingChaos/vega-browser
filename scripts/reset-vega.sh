#!/usr/bin/env bash
# Licensed under GPL-3.0. See LICENSE.
#
# Starts Vega over on this Mac, as if it had never been installed: the next launch runs the whole first-run
# sign-in and sync setup, and picks up nothing from an earlier install.
#
#   bash reset-vega.sh              moves Vega's data to a folder on your Desktop (you can put it back)
#   bash reset-vega.sh --delete     deletes it instead
#   bash reset-vega.sh --app        also removes Vega from Applications (then install the latest DMG again)
#
# Nothing here touches your Google account, iCloud or the Macs you sync with. Your sync data stays there and
# comes back when you sign in again.

set -uo pipefail
DELETE=false; APP=false
for arg in "$@"; do
  case "$arg" in --delete) DELETE=true ;; --app) APP=true ;; *) echo "unknown option $arg"; exit 1 ;; esac
done

# Vega, and the earlier builds it grew from: Vega copies an older one's data in on its first launch, which is the
# usual source of a profile or spaces nobody remembers adding.
IDS=(com.vega.browser com.gstudios.nook com.baingurley.nook io.browsewithnook.nook)
LIB="$HOME/Library"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/Desktop/Vega-reset-$STAMP"

echo "This resets Vega on this Mac: tabs, spaces, profiles, history, downloads list, notes and site logins."
$DELETE && echo "It DELETES them." || echo "It moves them to $BACKUP."
read -r -p "Continue? [y/N] " yes
[[ "$yes" == "y" || "$yes" == "Y" ]] || { echo "Nothing changed."; exit 0; }

osascript -e 'tell application id "com.vega.browser" to quit' >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Vega >/dev/null || break; sleep 1; done
pkill -x Vega 2>/dev/null; pkill -x Vega 2>/dev/null

moved=0
take() {
  local path="$1"
  [[ -e "$path" ]] || return
  if $DELETE; then rm -rf "$path"
  else
    local rel="${path#$HOME/}"
    mkdir -p "$BACKUP/$(dirname "$rel")" && mv "$path" "$BACKUP/$rel"
  fi
  echo "  removed ${path#$HOME/}"
  moved=$((moved + 1))
}

for id in "${IDS[@]}"; do
  take "$LIB/Application Support/$id"
  take "$LIB/WebKit/$id"
  take "$LIB/Caches/$id"
  take "$LIB/HTTPStorages/$id"
  take "$LIB/HTTPStorages/$id.binarycookies"
  take "$LIB/Saved Application State/$id.savedState"
  take "$LIB/Preferences/$id.plist"
  defaults delete "$id" >/dev/null 2>&1
done
take "$LIB/Application Support/Vega"
take "$LIB/Application Support/Vega"
killall cfprefsd >/dev/null 2>&1

# Sign-in tokens and the sync key live in the login Keychain. Deleting them can ask for your Mac password once.
for service in com.vega.browser.google com.vega.browser.syncKey com.vega.aiProvider; do
  while security delete-generic-password -s "$service" >/dev/null 2>&1; do :; done
done
for profileService in $(security dump-keychain 2>/dev/null | grep -oE '"svce"<blob>="com\.vega\.browser\.(google|syncKey)\.[0-9A-Fa-f-]+"' | sed -E 's/.*="(.*)"/\1/' | sort -u); do
  while security delete-generic-password -s "$profileService" >/dev/null 2>&1; do :; done
done
echo "  removed Vega's sign-in tokens and sync keys from the Keychain"

read -r -p "Also delete the passwords saved in Vega from this Mac's Keychain? They sync back if you use password sync. [y/N] " pw
if [[ "$pw" == "y" || "$pw" == "Y" ]]; then
  for domain in $(security dump-keychain 2>/dev/null | grep -oE '"sdmn"<blob>="com\.vega\.browser\.passwords[^"]*"' | sed -E 's/.*="(.*)"/\1/' | sort -u); do
    while security delete-internet-password -d "$domain" >/dev/null 2>&1; do :; done
  done
  echo "  removed Vega's saved passwords from the Keychain"
fi

if $APP && [[ -d /Applications/Vega.app ]]; then
  $DELETE && rm -rf /Applications/Vega.app || { mkdir -p "$BACKUP" && mv /Applications/Vega.app "$BACKUP/Vega.app"; }
  echo "  removed /Applications/Vega.app"
fi

echo
echo "Done: $moved item(s)."
$DELETE || echo "Put back by moving folders from $BACKUP into ~/Library. Delete the folder when you're sure."
echo "Now install the latest Vega (github.com/ClarifyingChaos/vega-browser/releases/latest) and open it: it starts with the sign-in step."
