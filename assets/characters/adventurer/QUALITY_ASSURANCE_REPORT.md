# Adventurer Asset Package — QA Report

## Completed checks
- Source dimensions confirmed: 1536 × 1024 pixels, RGBA.
- All extracted PNGs are RGBA.
- The source alpha channel is retained; no opaque black background was introduced.
- Frame numbering follows the left-to-right order of the visible groups.
- Animation categories are separated into their own directories.
- UI labels, class nameplate, description, and compass emblem are stored separately from character sprites.
- No character artwork was rescaled, repainted, or smoothed.

## Important source limitations
- This is a composed presentation sheet, not a formally gridded sprite atlas. Exact original per-frame boundaries and pivot points are not encoded.
- The source already contains transparency (including partially transparent edge pixels). The extraction preserves that alpha rather than applying a color-key operation that could erase dark outlines.
- The skill/special effects are close to neighboring artwork. The supplied crops preserve generous source windows, but should be visually reviewed in-engine before finalizing pivots and hitboxes.
- A separate portrait is not present; no portrait was invented.
- Frame counts are based on the visible groups in the sheet: Idle 4, Idle Alternate 4, Walk 4, Run 4, Attack 4, Skill/Special 4, Downed 2.

## Recommended final integration review
1. Open each sequence as a contact sheet and verify the intended frame bounds.
2. Tune per-frame pivots/anchors in the target engine; the presentation sheet does not provide metadata for them.
3. Confirm the skill effect crop boundaries and animation timing in-game.
