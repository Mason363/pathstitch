# DMG installer background

The release `.dmg` opens as a drag-to-install window: the Pathstitch app sits on
the left, the **Applications** folder on the right, and you drag one onto the
other.

## The leather background

`background.png` in this folder is the real thing: a 10 × 10 cm piece of veg-tan
leather, laser-cut and hand-stitched on an xTool S1, then photographed. It's
stored at 1000 × 1000 px (2×) so the installer window stays crisp on Retina.

`scripts/package_app.sh` automatically detects `background.png` and builds the
styled, positioned DMG, dropping the real app + Applications icons inside the two
stitched frames. If `background.png` is ever absent, it falls back to a plain
(un-styled) drag-install DMG, so packaging never breaks.

To remake it, see **`background-template.svg`** (the original layout guide) and
**`leather-dimensions.svg`** (the dimensioned engraving spec).

## Layout reference

| Item            | Icon center (pt) | Icon size |
|-----------------|------------------|-----------|
| Window content  | 500 × 500        | —         |
| Pathstitch.app  | (150, 238)       | 100       |
| Applications    | (352, 238)       | 100       |

Square (500 × 500 pt = 100 × 100 mm) so the 10 × 10 cm leather maps 1:1. Icon
centers are aligned to where the stitched frames actually landed in the photo
(fractional centers 0.301/0.704 across, 0.477 down), not the nominal grid.

Coordinates are in the window's content area, origin top-left — the same space
the Finder AppleScript in `package_app.sh` uses, so the art and the icons stay
aligned. To change the layout, edit the matching constants in `package_app.sh`
**and** this template together.
