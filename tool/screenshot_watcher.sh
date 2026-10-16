#!/bin/zsh
# Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
# Written by Martin Bundschuh.
#
# Wächter für integration_test/shopping_screenshots_test.dart: sobald die App
# im Simulator eine Markierung shot-<name>.req in ihrem tmp-Ordner ablegt,
# macht er ein Bild mit simctl und entfernt die Markierung.
#   tool/screenshot_watcher.sh <udid> <ablageordner> [bundle-id]
set -u
UDID="$1"; OUT="$2"; BID="${3:-com.example.togetherdo}"
mkdir -p "$OUT"
while true; do
  DIR=$(xcrun simctl get_app_container "$UDID" "$BID" data 2>/dev/null)/tmp
  if [[ -d "$DIR" ]]; then
    for f in "$DIR"/shot-*.req(N); do
      name=${${f:t}#shot-}; name=${name%.req}
      sleep 0.3
      xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "Bild: $name"
      rm -f "$f"
    done
  fi
  sleep 0.3
done
