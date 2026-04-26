#!/usr/bin/env bash
#
# Mirror static/videos_full/ -> static/videos/ as web-friendly minified .mp4s.
# Idempotent: skips files whose output is newer than the source.
#
# Usage:  bash scripts/minify_videos.sh

set -euo pipefail

SRC_DIR="static/videos_full"
DST_DIR="static/videos"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "error: ffmpeg not found in PATH" >&2
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "error: $SRC_DIR does not exist (run from repo root)" >&2
  exit 1
fi

human_size() {
  if [ ! -f "$1" ]; then echo "-"; return; fi
  du -h "$1" | awk '{print $1}'
}

encode_one() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  ffmpeg -nostdin -loglevel error -y -i "$src" \
    -c:v libx264 -crf 28 -preset slow \
    -vf "scale='min(1280,iw)':-2" \
    -pix_fmt yuv420p \
    -movflags +faststart \
    -r 30 \
    -an \
    "$dst"
}

# Process .mp4 first, then .mov, so a .mov is skipped when a sibling .mp4
# already produced the same output path.
process() {
  local src="$1"
  local rel="${src#$SRC_DIR/}"
  local stem="${rel%.*}"
  local dst="$DST_DIR/${stem}.mp4"

  if [ -f "$dst" ] && [ ! "$src" -nt "$dst" ]; then
    printf "skip    %-50s  %s\n" "$rel" "$(human_size "$dst")"
    return
  fi

  local before; before="$(human_size "$src")"
  encode_one "$src" "$dst"
  local after; after="$(human_size "$dst")"
  printf "encode  %-50s  %s -> %s\n" "$rel" "$before" "$after"
}

while IFS= read -r -d '' f; do process "$f"; done < <(find "$SRC_DIR" -type f -name "*.mp4" -print0)
while IFS= read -r -d '' f; do process "$f"; done < <(find "$SRC_DIR" -type f -name "*.mov" -print0)

echo
echo "Done."
du -sh "$SRC_DIR" "$DST_DIR" 2>/dev/null || true
