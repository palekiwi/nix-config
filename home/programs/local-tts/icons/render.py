import argparse
import subprocess
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ICONS = {"notification-interactive": "terminal", "notification-headless": "smart_toy"}
AXES = {"FILL": 0, "wght": 400, "GRAD": 0, "opsz": 48}
COLOR = "#F5F5F5"


def glyph_name(font, symbol):
    cmap = font.getBestCmap()
    sequence = [cmap[ord(c)] for c in symbol]
    for lookup in font["GSUB"].table.LookupList.Lookup:
        for table in lookup.SubTable:
            if table.LookupType == 7:
                table = table.ExtSubTable
            if table.LookupType != 4:
                continue
            for ligature in table.ligatures.get(sequence[0], []):
                if [sequence[0], *ligature.Component] == sequence:
                    return ligature.LigGlyph
    raise KeyError(symbol)


def svg(font, symbol):
    glyphs = font.getGlyphSet()
    pen = SVGPathPen(glyphs)
    glyphs[glyph_name(font, symbol)].draw(pen)
    em = font["head"].unitsPerEm
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" '
        f'viewBox="0 0 {em} {em}">'
        f'<path transform="matrix(1 0 0 -1 0 {em})" fill="{COLOR}" '
        f'd="{pen.getCommands()}"/></svg>\n'
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("font")
    parser.add_argument("--out", default=Path(__file__).parent, type=Path)
    parser.add_argument("--size", default=256, type=int)
    args = parser.parse_args()
    font = instantiateVariableFont(TTFont(args.font), AXES)
    for name, symbol in ICONS.items():
        path = args.out / f"{name}.svg"
        path.write_text(svg(font, symbol))
        subprocess.run(
            [
                "rsvg-convert",
                f"--width={args.size}",
                f"--height={args.size}",
                f"--output={args.out / f'{name}.png'}",
                str(path),
            ],
            check=True,
        )


if __name__ == "__main__":
    main()
