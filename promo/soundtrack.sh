#!/bin/sh
# Builds promo/out/music.wav from the licensed track plus the click and slider sounds.
# render.mjs picks that file up; or swap it into an existing render (see the last line).
#
# Track: "Minimal Technology" by NastelBom, Pixabay Content License (free for commercial use,
# no attribution required): https://pixabay.com/music/beats-minimal-technology-345194/
#
# Edit, on the video's 120 BPM grid:
#   video 0–25 s    = track 8.8–33.8 s; the track's first lift (13.8 s) lands on the 5.0 s drop
#   video 24.2–30 s = track 111.6–117.4 s, its own outro, crossfaded over 0.8 s into the end card
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
TRACK="$HERE/assets/music/nastelbom-minimal-technology.mp3"
OUT="$HERE/out"
mkdir -p "$OUT" "$(dirname "$TRACK")"

# Pixabay's license doesn't allow redistributing the track on its own, so it isn't committed:
# fetch it from Pixabay the first time.
if [ ! -s "$TRACK" ]; then
  curl -sSL -o "$TRACK" "https://cdn.pixabay.com/download/audio/2025/05/21/audio_280fb2e66e.mp3?filename=nastelbom-minimal-technology-345194.mp3"
fi

node "$HERE/music.mjs" --sfx-only >/dev/null

ffmpeg -y -loglevel error -i "$TRACK" -i "$OUT/sfx.wav" -filter_complex "
  [0:a]aresample=48000,asplit=2[a][b];
  [a]atrim=start=8.8:end=33.8,asetpts=PTS-STARTPTS,afade=t=in:d=0.4[body];
  [b]atrim=start=111.6:end=117.4,asetpts=PTS-STARTPTS[outro];
  [body][outro]acrossfade=d=0.8:c1=tri:c2=tri,afade=t=out:st=28.9:d=1.1[music];
  [music][1:a]amix=inputs=2:normalize=0:weights='1 0.9',loudnorm=I=-14:TP=-1:LRA=11,atrim=end=30[mix]" \
  -map "[mix]" -ar 48000 -ac 2 "$OUT/music.wav"
echo "Wrote $OUT/music.wav"
# Swap into a finished render without re-rendering the picture:
#   ffmpeg -y -i out/pointer-colors-promo.mp4 -i out/music.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest out/tmp.mp4 && mv out/tmp.mp4 out/pointer-colors-promo.mp4
