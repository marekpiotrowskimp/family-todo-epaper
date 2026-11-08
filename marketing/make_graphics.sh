#!/usr/bin/env bash
# make_graphics.sh — builds the LinkedIn graphics from the App Store screenshots.
#   images/linkedin_post_1080x1350.png            feed post (portrait 4:5, best reach in the feed)
#   images/linkedin_article_cover_1920x1080.png   article cover (16:9)
#   article/00_cover.png … 04_display.png         article cover and inline images
# Optional: photos/display.jpg (a photo of the real display) becomes article/04_display.png.
# Requires ImageMagick 7 (brew install imagemagick).
set -euo pipefail
cd "$(dirname "$0")"
SHOTS="../release_apple_store/screenshots/1320x2868/en"
ICON="../ios/FamilyTodo/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
PHOTO="photos/display.jpg"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SERIF="/System/Library/Fonts/Supplemental/Georgia.ttf"
SANS="/System/Library/Fonts/SFNS.ttf"
# App palette (ios/TodoCore/Sources/TodoCore/AppPalette.swift): paper, ink, secondary ink, terracotta accent.
BG1="#F4F1EA"; BG2="#E6DED0"; INK="#1C1C1E"; MUTED="#5E5A52"; ACCENT="#A8482A"

mkdir -p images article

# phone <screenshot> <width> <out>: screenshot in a dark rounded "device" frame with a soft shadow
phone() {
  local w=$2; local h=$(( w * 2868 / 1320 )); local r=$(( w * 14 / 100 ))
  local b=$(( w * 3 / 100 )); local fw=$(( w + 2*b )); local fh=$(( h + 2*b )); local fr=$(( r + b ))
  magick "$1" -alpha set -resize ${w}x${h}! \( -size ${w}x${h} xc:none -fill white -draw "roundrectangle 0,0,$((w-1)),$((h-1)),$r,$r" \) \
    -compose DstIn -composite "$TMP/screen.png"
  magick -size ${fw}x${fh} xc:none -fill "$INK" -draw "roundrectangle 0,0,$((fw-1)),$((fh-1)),$fr,$fr" \
    "$TMP/screen.png" -geometry +$b+$b -compose Over -composite \
    \( +clone -background "#3A3020" -shadow 35x$(( w / 12 ))+0+$(( w / 18 )) \) +swap -background none -layers merge +repage "$3"
}

icon() { # icon <size> <out>
  local s=$1; local r=$(( s * 22 / 100 ))
  magick "$ICON" -alpha set -resize ${s}x${s} \( -size ${s}x${s} xc:none -fill white -draw "roundrectangle 0,0,$((s-1)),$((s-1)),$r,$r" \) \
    -compose DstIn -composite "$2"
}

# ---------- Feed post 1080x1350 ----------
phone "$SHOTS/02_editor.png"  300 "$TMP/p_left.png"
phone "$SHOTS/03_history.png" 300 "$TMP/p_right.png"
phone "$SHOTS/01_list.png"    360 "$TMP/p_center.png"
icon 110 "$TMP/icon_s.png"
magick -size 1080x1350 gradient:"$BG1"-"$BG2" \
  "$TMP/icon_s.png" -gravity north -geometry +0+70 -composite \
  -font "$SERIF" -fill "$INK" -pointsize 78 -annotate +0+195 "Family To-Do" \
  -font "$SANS" -fill "$ACCENT" -pointsize 38 -annotate +0+300 "for your home e-paper display" \
  "$TMP/p_left.png"   -gravity northwest -geometry +60+480 -composite \
  "$TMP/p_right.png"  -gravity northeast -geometry +60+480 -composite \
  "$TMP/p_center.png" -gravity north -geometry +0+400 -composite \
  images/linkedin_post_1080x1350.png

# ---------- Article cover 1920x1080 ----------
phone "$SHOTS/02_editor.png"   320 "$TMP/c1.png"
phone "$SHOTS/01_list.png"     360 "$TMP/c2.png"
phone "$SHOTS/04_settings.png" 320 "$TMP/c3.png"
icon 130 "$TMP/icon_c.png"
magick -size 1920x1080 gradient:"$BG1"-"$BG2" \
  "$TMP/icon_c.png" -gravity northwest -geometry +170+300 -composite \
  -font "$SERIF" -fill "$INK" -pointsize 112 -annotate +160+470 "Family To-Do" \
  -font "$SANS" -fill "$MUTED" -pointsize 44 -annotate +166+600 "One task list for the whole family," \
  -font "$SANS" -fill "$MUTED" -pointsize 44 -annotate +166+660 "on an e-paper display in the hallway." \
  -font "$SANS" -fill "$ACCENT" -pointsize 34 -annotate +166+760 "iPhone · ESP32-S3 · open source" \
  "$TMP/c1.png" -gravity northwest -geometry +1000+170 -composite \
  "$TMP/c3.png" -gravity northwest -geometry +1470+170 -composite \
  "$TMP/c2.png" -gravity northwest -geometry +1220+90 -composite \
  images/linkedin_article_cover_1920x1080.png

# ---------- Article package ----------
cp images/linkedin_article_cover_1920x1080.png article/00_cover.png
n=1
for shot in 01_list 02_editor 04_settings; do
  phone "$SHOTS/$shot.png" 400 "$TMP/a.png"
  magick -size 1600x1000 gradient:"$BG1"-"$BG2" "$TMP/a.png" -gravity center -geometry +0+10 -composite \
    "article/0${n}_${shot#0?_}.png"
  n=$((n + 1))
done

if [ -f "$PHOTO" ]; then
  magick "$PHOTO" -auto-orient -resize 1600x1000^ -gravity center -extent 1600x1000 article/04_display.png
else
  rm -f article/04_display.png
  echo "No $PHOTO — article/04_display.png skipped (add a photo of the real display and run again)."
fi

echo "Done: $(pwd)/images, $(pwd)/article"
