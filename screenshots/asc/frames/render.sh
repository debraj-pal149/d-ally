#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(cd "$DIR/.." && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W=1320
H=2868

render() {
  local name="$1"
  local html="file://${DIR}/${name}.html"
  local dest="${OUT}/store-${name}.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=${W},${H} \
    --screenshot="${dest}" \
    --default-background-color=00000000 \
    "$html"
  # Ensure exact size
  sips -z "$H" "$W" "$dest" >/dev/null
  echo "wrote $dest ($(sips -g pixelWidth -g pixelHeight "$dest" | tr '\n' ' '))"
}

# Give fonts a moment on first load by rendering twice for first file
render "01-day"
sleep 1
render "01-day"
render "02-calendar"
render "03-week"
render "04-welcome"
ls -la "$OUT"/store-*.png
