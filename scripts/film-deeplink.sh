#!/bin/bash
# Open the project by deep link on a simulator, the way a scanned QR code does,
# and film the screen from that moment.
#
#   scripts/film-deeplink.sh <app> <out dir> [delay ms]
#
# Needs a booted simulator UDID in $UDID and Metro's port in $PORT (this
# script starts Metro itself, with REPRO_DELAY_MS so the manifest is slow on
# purpose). `idb` taps iOS's one-time "Open in …?" confirmation.
set -uo pipefail
APP=$1; OUT=$2; DELAY=${3:-4000}
: "${UDID:?simulator UDID}"; : "${PORT:?metro port}"
BUNDLE=build.simonsays.devlauncherrepro
SCHEME=exp+dev-launcher-loading-repro
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
rm -rf "$OUT"; mkdir -p "$OUT/frames"

tap_open() {
  local i lbl
  for i in $(seq 1 30); do
    lbl=$(idb ui describe-point --udid "$UDID" 264 468 2>/dev/null | python3 -c 'import json,sys
try: print((json.load(sys.stdin).get("AXLabel") or "").strip())
except Exception: pass')
    [ "$lbl" = Open ] && { idb ui tap --udid "$UDID" 264 468; return 0; }
    sleep 0.5
  done
}

xcrun simctl install "$UDID" "$APP"
(cd "$ROOT" && CI=1 REPRO_DELAY_MS=$DELAY npx expo start --dev-client --port "$PORT") > "$OUT/metro.log" 2>&1 &
METRO=$!
trap 'kill $METRO 2>/dev/null; pkill -P $METRO 2>/dev/null' EXIT
until curl -s "http://localhost:$PORT/status" | grep -q running; do sleep 1; done

URL="$SCHEME://expo-development-client/?url=$(node -p 'encodeURIComponent(process.argv[1])' "http://localhost:$PORT")&disableOnboarding=1"

# Prime: a fresh install's first launch is slow and iOS asks before the first
# external link; neither belongs in the film.
xcrun simctl openurl "$UDID" "$SCHEME://"; tap_open; sleep 12
xcrun simctl terminate "$UDID" "$BUNDLE"; sleep 3

T0=$(ms); echo "$T0" > "$OUT/t0"
( while [ ! -f "$OUT/stop" ]; do
    xcrun simctl io "$UDID" screenshot --type=jpeg "$OUT/frames/$(( $(ms) - T0 )).jpg" >/dev/null 2>&1
  done ) &
SHOTS=$!
xcrun simctl openurl "$UDID" "$URL"
sleep $(( DELAY * 3 / 1000 + 15 ))
touch "$OUT/stop"; wait $SHOTS
echo "frames: $(ls "$OUT/frames" | wc -l | tr -d ' ')"
