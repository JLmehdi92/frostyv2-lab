#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$here/fonts" "$work/"
node "$here/extract.js" "$root/.github/assets/onset-logo.svg" "$work/icon.json"
node "$here/build.js" "$here/template.html" "$work/icon.json" "$work/scene.html"
for theme in dark light; do
  SCENE="$work/scene.html" node "$here/render.js" video "vb=4x3&amb=0&bg=none&theme=$theme" 800 600 "$work/$theme.webm" 25 5.2 6 0.5 alpha
  ffmpeg -v error -y -c:v libvpx-vp9 -i "$work/$theme.webm" -vf "tpad=stop_mode=clone:stop_duration=2.8" -c:v libwebp_anim -lossless 0 -quality 82 -compression_level 6 -loop 0 "$root/.github/assets/onset-logo-$theme.webp"
done
