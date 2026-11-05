#!/bin/bash
# Compose App Store marketing frames (1320×2868) from UI screenshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RAW="$ROOT/raw"
OUT="$ROOT"
W=1320
H=2868
PHONE_W=1000
BG_DARK="#0B1820"
BG_LIGHT="#E8F4F8"
TMP="$ROOT/.tmp_compose"
rm -rf "$TMP"
mkdir -p "$TMP"

# Prefer SF Pro if present; else Helvetica.
TITLE_FONT="Helvetica-Bold"
BODY_FONT="Helvetica"
if [ -f "/System/Library/Fonts/Supplemental/Arial Bold.ttf" ]; then
  TITLE_FONT="/System/Library/Fonts/Supplemental/Arial Bold.ttf"
  BODY_FONT="/System/Library/Fonts/Supplemental/Arial.ttf"
fi

compose() {
  local bg="$1" title_fill="$2" sub_fill="$3" ui="$4" title="$5" sub="$6" dest="$7"
  magick "$ui" -resize "${PHONE_W}x" "$TMP/ui.png"
  # Soft shadow under the phone
  magick "$TMP/ui.png" \( +clone -background black -shadow 40x18+0+28 \) \
    +swap -background none -layers merge +repage "$TMP/phone.png"

  magick -size "${W}x${H}" "xc:${bg}" \
    \( -size $((W - 100))x220 -background none -fill "$title_fill" -font "$TITLE_FONT" \
       -pointsize 62 -gravity center caption:"${title}" \) \
    -gravity north -geometry +0+140 -composite \
    \( -size $((W - 140))x160 -background none -fill "$sub_fill" -font "$BODY_FONT" \
       -pointsize 32 -gravity center caption:"${sub}" \) \
    -gravity north -geometry +0+340 -composite \
    \( "$TMP/phone.png" \) \
    -gravity south -geometry +0+60 -composite \
    -quality 95 \
    "$dest"
  echo "wrote $dest ($(magick identify -format '%wx%h' "$dest"))"
}

DAY="${RAW}/day-dark.png"
WELCOME="${RAW}/welcome.png"
CAL="$(cd "$ROOT/../.." && pwd)/website/assets/app-calendar.png"
WEEK="$(cd "$ROOT/../.." && pwd)/website/assets/app-week.jpg"

compose "$BG_DARK" "#F2F2F7" "#9AA8B0" "$DAY" \
  "Your day" \
  "Mark what you kept as you go." \
  "$OUT/store-01-day.png"

compose "$BG_LIGHT" "#0B1820" "#4A5A63" "$CAL" \
  "Your calendar" \
  "See which days you kept." \
  "$OUT/store-02-calendar.png"

compose "$BG_LIGHT" "#0B1820" "#4A5A63" "$WEEK" \
  "Your week" \
  "On Sunday, see it in one place." \
  "$OUT/store-03-week.png"

compose "$BG_DARK" "#F2F2F7" "#9AA8B0" "$WELCOME" \
  "Show up every day." \
  "Reminders for everyday tasks." \
  "$OUT/store-04-welcome.png"

rm -rf "$TMP"
ls -la "$OUT"/store-*.png
