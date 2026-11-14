#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$here/fonts" "$work/"
node "$here/extract.js" "$root/.github/assets/onset-logo.svg" "$work/icon.json"
node "$here/build.js" "$here/template.html" "$work/icon.json" "$work/scene.html"
SCENE="$work/scene.html" node "$here/render.js" video 'vb=4x3&amb=0' 800 600 "$work/logo.mp4" 25 5.2 6 0.5 h264
ffmpeg -v error -y -i "$work/logo.mp4" -vf "tpad=stop_mode=clone:stop_duration=2.8,split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" -loop 0 "$root/.github/assets/onset-logo.gif"
