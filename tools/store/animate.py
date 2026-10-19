"""
Puts screenshots of the viewer together into one animated WebP for the README.

    animate.py OUT.webp MARGIN RADIUS SCENE [SCENE…]

A SCENE is either the stem of a sequence that `viewer.py … --frames N` saved (STEM-0000.png…
and STEM-times.txt), played with its real timing, or one screenshot held for a while, as
FILE.png:MILLISECONDS. MARGIN is the desktop stand-in around the widget, cut off; RADIUS rounds
the corners, as the widget's own are. Needs Pillow.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SMOOTH = 4


def rounded_mask(size, radius):
    """An anti-aliased mask with rounded corners, drawn large and scaled down."""
    width, height = size
    mask = Image.new("L", (width * SMOOTH, height * SMOOTH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width * SMOOTH - 1, height * SMOOTH - 1), radius * SMOOTH, fill=255)

    return mask.resize(size, Image.LANCZOS)


def scene_frames(scene):
    """The frames of a scene, each with how long it stays, in milliseconds."""
    if ":" in scene and scene.rsplit(":", 1)[1].isdigit():
        path, hold = scene.rsplit(":", 1)

        return [(Image.open(path), int(hold))]

    paths = sorted(Path(scene).parent.glob(f"{Path(scene).name}-[0-9][0-9][0-9][0-9].png"))
    times = [int(line) for line in Path(f"{scene}-times.txt").read_text().split()]
    steps = [later - earlier for earlier, later in zip(times, times[1:])]
    # The last frame stays as long as the others did on average.
    steps.append(round(sum(steps) / len(steps)) if steps else 100)

    return [(Image.open(path), step) for path, step in zip(paths, steps)]


def main():
    out, margin, radius, scenes = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:]
    frames, durations, mask = [], [], None

    for scene in scenes:
        for image, duration in scene_frames(scene):
            image = image.convert("RGBA")
            image = image.crop((margin, margin, image.width - margin, image.height - margin))
            mask = mask or rounded_mask(image.size, radius)
            image.putalpha(mask)
            frames.append(image)
            durations.append(duration)

    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0, quality=85, method=6, allow_mixed=True)
    print(f"{out}: {len(frames)} frames, {sum(durations) / 1000:.1f} s, {Path(out).stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
