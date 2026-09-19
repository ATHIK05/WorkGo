#!/bin/bash
AST_DIR="/var/lib/asterisk/sounds/workgo"
SRC_DIR="/mnt/d/WorkGo/backend/sounds"
mkdir -p "$AST_DIR"
for f in "$SRC_DIR"/*.wav; do
  name=$(basename "$f" .wav)
  dest="$AST_DIR/${name}.wav"
  ffmpeg -y -i "$f" -ar 8000 -ac 1 -acodec pcm_s16le "$dest" -loglevel quiet && echo "[OK] $name"
done
echo "Sync complete"
