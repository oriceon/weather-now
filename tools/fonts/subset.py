"""
Makes the fonts that come with the widget, from the static fonts of an Inter release
(https://github.com/rsms/inter/releases, extras/ttf/): the weights the widget draws with, cut down
to the Latin scripts, the punctuation and the arrows it shows. Glyphs it lacks, in the name of a
place in another script, come from the fonts of the system. Needs fontTools.

    subset.py INTER_TTF_FOLDER package/contents/fonts
    subset.py --rename package/contents/fonts

The fonts are named "Weather Now Inter": loaded, a font belongs to the whole Plasma process, and
under the name of Inter this cut, without Cyrillic or Greek, took the place of an Inter installed on
the system in the other widgets. Inter is under the SIL Open Font License, without a Reserved Font
Name, which allows a font cut down to be renamed; its licence goes along, as Inter-LICENSE.txt.
"""
import shutil
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

FONTS = ["Inter-Regular.ttf", "Inter-SemiBold.ttf", "Inter-Bold.ttf", "InterDisplay-SemiBold.ttf"]
FAMILY = "Weather Now Inter"
# Family, unique and full names, typographic and WWS families; the PostScript name has no spaces.
NAMED = (1, 3, 4, 16, 21)
POSTSCRIPT = 6

UNICODES = [
    *range(0x0020, 0x007F),  # Basic Latin
    *range(0x00A0, 0x0180),  # Latin-1 Supplement and Latin Extended-A, with ă, î, â and the cedilla forms ş, ţ
    *range(0x0218, 0x021C),  # ș, ț and their capitals, with the comma below
    *range(0x2010, 0x2028),  # dashes, quotes, the bullet and the ellipsis
    *range(0x2030, 0x203B),  # per mille and the angle quotes
    0x20AC,  # euro
    *range(0x2190, 0x2196),  # arrows: ↑ ↓ for the highest and lowest temperatures
    0x2212,  # minus
]


def rename(font):
    """Gives the font the family of the widget: "Inter Display" becomes "Weather Now Inter Display"."""
    for record in font["name"].names:
        text = record.toUnicode()

        if record.nameID in NAMED and FAMILY not in text:
            record.string = text.replace("Inter", FAMILY, 1)
        elif record.nameID == POSTSCRIPT and not text.startswith("WeatherNow"):
            record.string = "WeatherNow" + text


def main():
    if sys.argv[1] == "--rename":
        for name in FONTS:
            font = TTFont(Path(sys.argv[2]) / name)
            rename(font)
            font.save(Path(sys.argv[2]) / name)

        return

    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)

    options = subset.Options()
    # The usual features, and figures of one width, so that a temperature does not shift as it changes.
    options.layout_features.append("tnum")
    # FreeType draws Plasma's text without the TrueType hinting by default; it is most of the size.
    options.hinting = False
    # The typographic family (16, 17) keeps the weights together as one family, "Inter".
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True

    for name in FONTS:
        font = subset.load_font(source / name, options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        rename(font)
        subset.save_font(font, target / name, options)
        print(f"{name}: {(source / name).stat().st_size // 1024} KB -> {(target / name).stat().st_size // 1024} KB")

    shutil.copyfile(source / "LICENSE.txt", target / "Inter-LICENSE.txt")


if __name__ == "__main__":
    main()
