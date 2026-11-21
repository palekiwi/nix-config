# Notification icons

Desktop notification icons, one per source:

- `notification-interactive.{svg,png}`: Material Symbols `terminal`
  (codepoint U+EB8E), for interactive pi sessions.
- `notification-headless.{svg,png}`: Material Symbols `smart_toy`
  (codepoint U+F06C), for headless agent runs.

## Attribution

Material Symbols, Copyright 2026 Google LLC, from
https://github.com/google/material-design-icons (revision
5a4e1b7fd26f11ce3d2abf7d7fcd13274f874e6c, nixpkgs `material-symbols`
4.0.0-unstable-2026-05-08, font version 2.938). Licensed under the Apache
License, Version 2.0; a copy is in [LICENSE](LICENSE).

Modifications: the glyphs were extracted from the variable font
`MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf` at FILL 0, wght 400,
GRAD 0, opsz 48, recoloured to a single fill `#F5F5F5`, and rasterised
to 256x256 PNGs with transparent background.

## Regenerating

`render.py` looks each symbol up by its ligature name in the font, so a
wrong name fails instead of picking another glyph. From this directory:

```sh
pkgs='(builtins.getFlake (toString ../../..)).inputs.nixpkgs.legacyPackages.x86_64-linux'
font=$(nix build --no-link --print-out-paths --impure --expr "$pkgs.material-symbols")
nix shell --impure --expr "with $pkgs; [ (python3.withPackages (p: [ p.fonttools ])) librsvg ]" \
  --command python3 render.py "$font/share/fonts/truetype/MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf"
```

The flake is the home flake (`home/flake.nix`), whose `nixpkgs` input
pins the font version.
