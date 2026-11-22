# Adventurer Animation Manifest

Source: `source_sprite_sheet.png` (1536 × 1024 RGBA).
All frame crops are direct source-pixel crops; no resampling or repainting was applied.
The source already contains an alpha channel. Its transparency was retained rather than applying a destructive black-key removal.

## Animation sequences

### Idle
- Frame count: 4
- Recommended loop: Yes, suggested
- Ordered frames:
  - `adventurer_idle_01.png` — extracted canvas 150 × 145 px; source window `[495, 130, 645, 275]`
  - `adventurer_idle_02.png` — extracted canvas 150 × 145 px; source window `[595, 130, 745, 275]`
  - `adventurer_idle_03.png` — extracted canvas 150 × 145 px; source window `[695, 130, 845, 275]`
  - `adventurer_idle_04.png` — extracted canvas 150 × 145 px; source window `[795, 130, 945, 275]`
- Notes: Frames are ordered left-to-right as presented in the sheet; transparent padding provides a consistent per-sequence canvas.

### Idle Alternate
- Frame count: 4
- Recommended loop: Yes, suggested
- Ordered frames:
  - `adventurer_idle_alternate_01.png` — extracted canvas 150 × 150 px; source window `[1015, 130, 1165, 280]`
  - `adventurer_idle_alternate_02.png` — extracted canvas 150 × 150 px; source window `[1130, 130, 1280, 280]`
  - `adventurer_idle_alternate_03.png` — extracted canvas 150 × 150 px; source window `[1245, 130, 1395, 280]`
  - `adventurer_idle_alternate_04.png` — extracted canvas 150 × 150 px; source window `[1365, 130, 1515, 280]`
- Notes: Frames are ordered left-to-right as presented in the sheet; transparent padding provides a consistent per-sequence canvas.

### Walk
- Frame count: 4
- Recommended loop: Yes, suggested
- Ordered frames:
  - `adventurer_walk_01.png` — extracted canvas 150 × 175 px; source window `[490, 365, 640, 540]`
  - `adventurer_walk_02.png` — extracted canvas 150 × 175 px; source window `[600, 365, 750, 540]`
  - `adventurer_walk_03.png` — extracted canvas 150 × 175 px; source window `[710, 365, 860, 540]`
  - `adventurer_walk_04.png` — extracted canvas 150 × 175 px; source window `[815, 365, 965, 540]`
- Notes: Frames are ordered left-to-right as presented in the sheet; transparent padding provides a consistent per-sequence canvas.

### Run
- Frame count: 4
- Recommended loop: Yes, suggested
- Ordered frames:
  - `adventurer_run_01.png` — extracted canvas 150 × 175 px; source window `[995, 365, 1145, 540]`
  - `adventurer_run_02.png` — extracted canvas 150 × 175 px; source window `[1115, 365, 1265, 540]`
  - `adventurer_run_03.png` — extracted canvas 150 × 175 px; source window `[1235, 365, 1385, 540]`
  - `adventurer_run_04.png` — extracted canvas 150 × 175 px; source window `[1375, 365, 1525, 540]`
- Notes: Frames are ordered left-to-right as presented in the sheet; transparent padding provides a consistent per-sequence canvas.

### Attack
- Frame count: 4
- Recommended loop: No / event-triggered suggestion
- Ordered frames:
  - `adventurer_attack_01.png` — extracted canvas 150 × 195 px; source window `[460, 595, 610, 790]`
  - `adventurer_attack_02.png` — extracted canvas 150 × 195 px; source window `[585, 595, 735, 790]`
  - `adventurer_attack_03.png` — extracted canvas 150 × 195 px; source window `[710, 595, 860, 790]`
  - `adventurer_attack_04.png` — extracted canvas 150 × 195 px; source window `[835, 595, 985, 790]`
- Notes: Sword poses and visible slash artwork are retained within the selected source windows.

### Skill Special
- Frame count: 4
- Recommended loop: No / event-triggered suggestion
- Ordered frames:
  - `adventurer_skill_special_01.png` — extracted canvas 150 × 220 px; source window `[985, 585, 1135, 805]`
  - `adventurer_skill_special_02.png` — extracted canvas 150 × 220 px; source window `[1100, 585, 1250, 805]`
  - `adventurer_skill_special_03.png` — extracted canvas 150 × 220 px; source window `[1225, 585, 1375, 805]`
  - `adventurer_skill_special_04.png` — extracted canvas 150 × 220 px; source window `[1370, 585, 1520, 805]`
- Notes: Blue magical effects are included in the source windows; inspect edge clearance before engine import because adjacent effect artwork is tightly packed.

### Downed
- Frame count: 2
- Recommended loop: No / event-triggered suggestion
- Ordered frames:
  - `adventurer_downed_01.png` — extracted canvas 225 × 150 px; source window `[25, 820, 235, 970]`
  - `adventurer_downed_02.png` — extracted canvas 225 × 150 px; source window `[225, 820, 450, 970]`
- Notes: Two distinct horizontal downed poses are separated; source crops retain their original orientations.

## Additional extracted assets

- `showcase/adventurer_showcase.png` — 380 × 520 px; source window `[30, 155, 410, 675]`
- `icons/adventurer_class_compass.png` — 127 × 125 px; source window `[28, 20, 155, 145]`
- `ui/adventurer_nameplate.png` — 418 × 94 px; source window `[112, 34, 530, 128]`
- `ui/adventurer_class_description.png` — 335 × 91 px; source window `[165, 122, 500, 213]`
- `ui/label_idle.png` — 165 × 51 px; source window `[585, 72, 750, 123]`
- `ui/label_idle_alternate.png` — 240 × 51 px; source window `[1070, 72, 1310, 123]`
- `ui/label_walk.png` — 145 × 52 px; source window `[530, 326, 675, 378]`
- `ui/label_run.png` — 135 × 52 px; source window `[1040, 326, 1175, 378]`
- `ui/label_attack.png` — 150 × 49 px; source window `[525, 558, 675, 607]`
- `ui/label_skill_special.png` — 225 × 50 px; source window `[1040, 558, 1265, 608]`
- `ui/label_downed.png` — 175 × 55 px; source window `[40, 765, 215, 820]`
- Separate character portrait: not present as an independent asset in the source sheet; no derivative portrait was fabricated.
- The full source sheet is preserved at `source_sprite_sheet.png` for provenance and rechecking.

## Source frame dimensions
- The source is a composed presentation sheet, not a uniform grid atlas. Individual original frame boundaries are not explicitly marked.
- Therefore, the manifest records the extraction windows and output canvas dimensions; these should not be interpreted as authoritative native per-frame bounding boxes.