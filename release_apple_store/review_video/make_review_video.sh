#!/usr/bin/env bash
# make_review_video.sh — assembles the App Review demo video (1920×1080, 30 fps, H.264, no audio)
# for an unlisted YouTube upload.
#
#   footage/NN_name.mov|mp4|m4v   your clips, in order (see SHOT_LIST.md); NN = shot number
#   footage/NN_name.txt           optional caption for that clip (first line); otherwise the default
#                                 caption of shot NN from the table below is used
#
#   ./make_review_video.sh   →  out/review_video.mp4
#   Without footage it builds out/review_video_DRAFT.mp4 from the App Store screenshots, with a
#   placeholder card where the hardware clips go, so you can check the structure.
#
# Requires ffmpeg and ImageMagick 7 (brew install ffmpeg imagemagick).
# footage/ and out/ are ignored by git: the clips show your home.
set -euo pipefail
cd "$(dirname "$0")"
SHOTS="../screenshots/1320x2868/en"
ICON="../../ios/FamilyTodo/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SANS="/System/Library/Fonts/SFNS.ttf"
SERIF="/System/Library/Fonts/Supplemental/Georgia.ttf"
PAPER="#F4F1EA"; INK="#1C1C1E"; MUTED="#5E5A52"; ACCENT="#A8482A"
W=1920; H=1080; FPS=30
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p out footage

caption_for() { # default caption of shot NN
  case "$1" in
    01) echo "The e-paper display at home, built from the open-source project" ;;
    02) echo "Adding a task in the app, next to the display" ;;
    03) echo "The app syncs over Bluetooth Low Energy (no pairing)" ;;
    04) echo "The display refreshes and shows the new task" ;;
    05) echo "Marking the task as done in the app" ;;
    06) echo "After the sync the task disappears from the display" ;;
    07) echo "A second phone sees the task of another family member" ;;
    *)  echo "" ;;
  esac
}

encode() { ffmpeg -loglevel error -y "$@" -r $FPS -pix_fmt yuv420p -c:v libx264 -preset medium -crf 20 -an; }

card() { # card <out.mp4> <seconds> <title> <line1> [line2]
  local s=$(( 150 )); local r=$(( s * 22 / 100 ))
  magick "$ICON" -alpha set -resize ${s}x${s} \( -size ${s}x${s} xc:none -fill white -draw "roundrectangle 0,0,$((s-1)),$((s-1)),$r,$r" \) \
    -compose DstIn -composite "$TMP/icon.png"
  magick -size ${W}x${H} xc:"$PAPER" \
    "$TMP/icon.png" -gravity north -geometry +0+250 -composite \
    -font "$SERIF" -fill "$INK" -pointsize 84 -gravity north -annotate +0+450 "$3" \
    -font "$SANS" -fill "$MUTED" -pointsize 44 -annotate +0+590 "$4" \
    -font "$SANS" -fill "$ACCENT" -pointsize 40 -annotate +0+670 "${5:-}" \
    "$TMP/card.png"
  encode -loop 1 -t "$2" -i "$TMP/card.png" -vf "fps=$FPS" "$1"
}

caption_png() { # caption_png <text> <out.png>: dark bar for the bottom of the frame
  magick -size ${W}x140 xc:"rgba(28,28,30,0.80)" -font "$SANS" -pointsize 50 -fill white \
    -gravity center -annotate +0+0 "$1" "$2"
}

clip() { # clip <in> <caption> <out.mp4>
  caption_png "$2" "$TMP/cap.png"
  encode -i "$1" -i "$TMP/cap.png" -filter_complex \
    "[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0xF4F1EA,fps=$FPS,setsar=1[v];[v][1:v]overlay=0:H-h" \
    "$3"
}

slide() { # slide <screenshot> <caption> <out.mp4>: app screenshot centred on paper, 4 s
  magick -size ${W}x${H} xc:"$PAPER" \( "$1" -resize x900 \) -gravity north -geometry +0+20 -composite "$TMP/slide.png"
  caption_png "$2" "$TMP/cap.png"
  encode -loop 1 -t 4 -i "$TMP/slide.png" -i "$TMP/cap.png" -filter_complex "[0:v]fps=$FPS,setsar=1[v];[v][1:v]overlay=0:H-h" "$3"
}

segments=()
n=0
add() { segments+=("$1"); }

card "$TMP/s$((n++)).mp4" 4 "Family To-Do for E-Paper" "Demo video for App Review" "iPhone app + DIY e-paper display (ESP32-S3)"
add "$TMP/s$((n-1)).mp4"

shopt -s nullglob
clips=(footage/[0-9][0-9]_*.mov footage/[0-9][0-9]_*.mp4 footage/[0-9][0-9]_*.m4v footage/[0-9][0-9]_*.MOV footage/[0-9][0-9]_*.MP4)
IFS=$'\n' clips=($(printf '%s\n' "${clips[@]}" | sort)); unset IFS

if [ ${#clips[@]} -gt 0 ]; then
  OUT=out/review_video.mp4
  for f in "${clips[@]}"; do
    base="${f%.*}"; num="$(basename "$f" | cut -c1-2)"
    text="$(caption_for "$num")"
    [ -f "$base.txt" ] && text="$(head -n 1 "$base.txt")"
    echo "clip $f — ${text:-<no caption>}"
    if [ -n "$text" ]; then clip "$f" "$text" "$TMP/s$n.mp4"
    else encode -i "$f" -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0xF4F1EA,setsar=1" "$TMP/s$n.mp4"; fi
    add "$TMP/s$n.mp4"; n=$((n + 1))
  done
else
  OUT=out/review_video_DRAFT.mp4
  echo "No clips in footage/ — building a DRAFT (see SHOT_LIST.md for what to record)."
  slide "$SHOTS/01_list.png"   "The app: the family's tasks" "$TMP/s$n.mp4";               add "$TMP/s$n.mp4"; n=$((n + 1))
  slide "$SHOTS/02_editor.png" "Adding a task: priority, due date, reminder, note" "$TMP/s$n.mp4"; add "$TMP/s$n.mp4"; n=$((n + 1))
  card "$TMP/s$n.mp4" 4 "[ Hardware clips go here ]" "Record shots 01–06 from SHOT_LIST.md" "and put them in footage/"
  add "$TMP/s$n.mp4"; n=$((n + 1))
fi

card "$TMP/s$n.mp4" 5 "No account · No server" "Bluetooth is used only to talk to your own display" "github.com/marekpiotrowskimp/family-todo-epaper"
add "$TMP/s$n.mp4"

: > "$TMP/list.txt"
for s in "${segments[@]}"; do echo "file '$s'" >> "$TMP/list.txt"; done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
echo "Done: $(pwd)/$OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | cut -d. -f1) s)"
