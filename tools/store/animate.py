"""
Puts screenshots of the viewer together into one animation: an animated WebP for the README, or
an animated GIF for the KDE Store, which shows no WebP. GIFs are encoded with gifski.

    animate.py OUT.webp|OUT.gif MARGIN RADIUS [--scale FACTOR] [--every N] [--loop-blend K] SCENE [SCENE…]

A SCENE is either the stem of a sequence that `viewer.py … --frames N` saved (STEM-0000.png…
and STEM-times.txt), played with its real timing, or one screenshot held for a while, as
FILE.png:MILLISECONDS. MARGIN is the desktop stand-in around the widget, cut off; RADIUS rounds
the corners, as the widget's own are. --scale shrinks the frames and --every keeps one frame in N,
both to keep a GIF small. --loop-blend fades the last K frames of each sequence into the frames
before its start, so that the animation starts again without a jump; the sequence has to have
K frames more than it shows. Needs Pillow.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SMOOTH = 4


def rounded_mask(size, radius):
    """An anti-aliased mask with rounded corners, drawn large and scaled down."""
    width, height = size
    mask = Image.new("L", (width * SMOOTH, height * SMOOTH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width * SMOOTH - 1, height * SMOOTH - 1), radius * SMOOTH, fill=255)

    return mask.resize(size, Image.LANCZOS)


def opened(path):
    return lambda: Image.open(path).convert("RGBA")


def blended(path, earlier, weight):
    """`path` faded into `earlier`: all `path` at weight 0, all `earlier` at weight 1."""
    return lambda: Image.blend(Image.open(path).convert("RGBA"), Image.open(earlier).convert("RGBA"), weight)


def scene_frames(scene, loop_blend):
    """The frames of a scene, each as something that opens it and how long it stays, in milliseconds."""
    if ":" in scene and scene.rsplit(":", 1)[1].isdigit():
        path, hold = scene.rsplit(":", 1)

        return [(opened(path), int(hold))]

    paths = sorted(Path(scene).parent.glob(f"{Path(scene).name}-[0-9][0-9][0-9][0-9].png"))
    times = [int(line) for line in Path(f"{scene}-times.txt").read_text().split()]
    steps = [later - earlier for earlier, later in zip(times, times[1:])]
    # The last frame stays as long as the others did on average.
    steps.append(round(sum(steps) / len(steps)) if steps else 100)

    if loop_blend == 0:
        return [(opened(path), step) for path, step in zip(paths, steps)]

    # Frame K is the first one shown; the last K shown fade, one step at a time, into frames 0…K-1,
    # so that the last one shown is frame K-1 and the next one, frame K again, follows it.
    shown = len(paths) - loop_blend
    frames = []

    for index in range(shown):
        source = index + loop_blend
        fade = index - (shown - loop_blend) + 1

        if fade > 0:
            frames.append((blended(paths[source], paths[source - shown], fade / loop_blend), steps[source]))
        else:
            frames.append((opened(paths[source]), steps[source]))

    return frames


def save_gif(out, frames, durations, fps=15):
    """
    Hands the frames to gifski (https://gif.ski), which gives every frame thousands of shades in
    256 colours, with dithering that does not crawl, where Pillow cuts the gradients of the sky into
    bands. gifski plays frames at a steady rate, so a frame that stays longer is repeated; it joins
    the repeats back into one. GIFSKI may name the program; otherwise it is looked for on the PATH.
    """
    gifski = os.environ.get("GIFSKI") or shutil.which("gifski")

    if not gifski:
        sys.exit("gifski is missing: see https://gif.ski, or name it in GIFSKI")

    with tempfile.TemporaryDirectory() as folder:
        paths = []

        for frame, duration in zip(frames, durations):
            for _ in range(max(1, round(duration * fps / 1000))):
                path = f"{folder}/{len(paths):05d}.png"

                if paths and _ > 0:
                    shutil.copyfile(paths[-1], path)
                else:
                    frame.save(path)

                paths.append(path)

        subprocess.run([gifski, "--quiet", "--quality", "100", "--extra", "--fps", str(fps), "--output", out, *paths], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("margin", type=int)
    parser.add_argument("radius", type=int)
    parser.add_argument("scenes", nargs="+")
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--every", type=int, default=1)
    parser.add_argument("--loop-blend", type=int, default=0)
    arguments = parser.parse_args()

    frames, durations, mask = [], [], None

    for scene in arguments.scenes:
        kept = []

        # A frame that is left out lends its time to the one kept before it.
        for index, (open_frame, duration) in enumerate(scene_frames(scene, arguments.loop_blend)):
            if index % arguments.every == 0 or not kept:
                kept.append([open_frame, duration])
            else:
                kept[-1][1] += duration

        for open_frame, duration in kept:
            image = open_frame()
            image = image.crop((arguments.margin, arguments.margin, image.width - arguments.margin, image.height - arguments.margin))

            if arguments.scale != 1.0:
                image = image.resize((round(image.width * arguments.scale), round(image.height * arguments.scale)), Image.LANCZOS)

            mask = mask or rounded_mask(image.size, round(arguments.radius * arguments.scale))
            # The corners cut off here, and whatever was already transparent, stay transparent.
            image.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
            frames.append(image)
            durations.append(duration)

    if arguments.out.endswith(".gif"):
        save_gif(arguments.out, frames, durations)
    else:
        frames[0].save(arguments.out, save_all=True, append_images=frames[1:], duration=durations, loop=0, quality=85, method=6, allow_mixed=True)

    print(f"{arguments.out}: {len(frames)} frames, {sum(durations) / 1000:.1f} s, {Path(arguments.out).stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
