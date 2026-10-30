"""Renders the README screenshots and shrinks them, in one command.

Runs tool/readme_shots/readme_shots_test.dart (the real widgets, fake data,
see that file), which writes full-colour PNGs to .github/assets/screenshots/,
then turns each into a 256-colour dithered PNG (about a quarter of the size).

Usage, from anywhere (needs Flutter on the PATH and Pillow):
    python3 tool/readme_shots/render.py
"""
import os
import shutil
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHOTS = os.path.join(ROOT, '.github', 'assets', 'screenshots')
TEST = os.path.join('tool', 'readme_shots', 'readme_shots_test.dart')


def main():
    flutter = shutil.which('flutter')
    if flutter is None:
        sys.exit('flutter is not on the PATH')
    subprocess.run([flutter, 'test', TEST], cwd=ROOT, check=True)
    for name in sorted(os.listdir(SHOTS)):
        if not name.endswith('.png'):
            continue
        path = os.path.join(SHOTS, name)
        before = os.path.getsize(path)
        image = Image.open(path).convert('RGB')
        image.quantize(
            256, method=Image.Quantize.MEDIANCUT,
            dither=Image.Dither.FLOYDSTEINBERG,
        ).save(path, optimize=True)
        print(f'{name}: {before // 1024} KB -> {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    main()
