import os
from PIL import Image

BRAIN_DIR = r"C:\Users\USER\.gemini\antigravity\brain\9ac87922-6c08-43b4-8dad-08d6b9c06738\.user_uploaded"
IMG_CLASSES_PATH = os.path.join(BRAIN_DIR, "media_1795078208435_3a85035f.jpg")
IMG_ADV_PATH = os.path.join(BRAIN_DIR, "media_1795078449527_8cfd48c6.png")

PROJECT_DIR = r"E:\myLittleProject\echoes_of_aether"
OUTPUT_CHAR_DIR = os.path.join(PROJECT_DIR, r"assets\char")
OUTPUT_FRAMES_DIR = os.path.join(PROJECT_DIR, r"assets\char\frames")
OUTPUT_ICONS_DIR = os.path.join(PROJECT_DIR, r"assets\icons\class")

os.makedirs(OUTPUT_CHAR_DIR, exist_ok=True)
os.makedirs(OUTPUT_FRAMES_DIR, exist_ok=True)
os.makedirs(OUTPUT_ICONS_DIR, exist_ok=True)

def is_bg_pixel(r, g, b):
    # Gray or white checkerboard pattern
    return r > 212 and g > 212 and b > 212 and abs(r - g) < 20 and abs(g - b) < 20 and abs(r - b) < 20

def remove_background_bfs(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visited = set()
    queue = []

    # Queue pixels along all 4 boundaries
    for x in range(w):
        if is_bg_pixel(*px[x, 0][:3]):
            queue.append((x, 0))
            visited.add((x, 0))
        if is_bg_pixel(*px[x, h - 1][:3]):
            queue.append((x, h - 1))
            visited.add((x, h - 1))
    for y in range(h):
        if is_bg_pixel(*px[0, y][:3]) and (0, y) not in visited:
            queue.append((0, y))
            visited.add((0, y))
        if is_bg_pixel(*px[w - 1, y][:3]) and (w - 1, y) not in visited:
            queue.append((w - 1, y))
            visited.add((w - 1, y))

    # BFS flood-fill to clear transparent background
    while queue:
        cx, cy = queue.pop(0)
        px[cx, cy] = (0, 0, 0, 0)
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                if is_bg_pixel(*px[nx, ny][:3]):
                    visited.add((nx, ny))
                    queue.append((nx, ny))

    return im

def crop_and_clean(im, bbox, remove_bg=True):
    crop = im.crop(bbox)
    if remove_bg:
        crop = remove_background_bfs(crop)
    b = crop.getbbox()
    if b:
        crop = crop.crop(b)
    return crop

print("Loading reference images...")
img_classes = Image.open(IMG_CLASSES_PATH)
img_adv = Image.open(IMG_ADV_PATH)

# =========================================================================
# 1. PROCESS ADVENTURER (hero_base)
# =========================================================================
print("Processing Adventurer (hero_base)...")
# Portrait
adv_portrait = crop_and_clean(img_adv, (21, 155, 245, 650), remove_bg=False)
adv_portrait.save(os.path.join(OUTPUT_CHAR_DIR, "hero_base.png"))
print(f"  hero_base portrait saved: {adv_portrait.size}")

# Crest Icon
adv_crest = crop_and_clean(img_adv, (20, 25, 95, 88), remove_bg=False)
adv_crest.save(os.path.join(OUTPUT_ICONS_DIR, "crest_adventurer.png"))

# Gameplay Frames
# Idle 0 (Front) & Idle 1 (Side/3/4)
adv_idle0 = crop_and_clean(img_adv, (320, 110, 395, 205), remove_bg=False)
adv_idle1 = crop_and_clean(img_adv, (395, 110, 465, 205), remove_bg=False)
adv_idle0.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_idle0.png"))
adv_idle1.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_idle1.png"))

# Walk 0 & Walk 1
adv_walk0 = crop_and_clean(img_adv, (320, 250, 395, 345), remove_bg=False)
adv_walk1 = crop_and_clean(img_adv, (395, 250, 465, 345), remove_bg=False)
adv_walk0.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_walk0.png"))
adv_walk1.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_walk1.png"))

# Attack (frame with sword slash VFX)
adv_attack = crop_and_clean(img_adv, (550, 390, 665, 520), remove_bg=False)
adv_attack.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_attack.png"))

# Downed (frame on ground)
adv_downed = crop_and_clean(img_adv, (20, 570, 155, 660), remove_bg=False)
adv_downed.save(os.path.join(OUTPUT_FRAMES_DIR, "hero_base_downed.png"))
print("  hero_base frames saved successfully!")

# =========================================================================
# 2. PROCESS 9 CLASSES FROM MASTER SHEET
# =========================================================================
classes_grid = [
    [("vanguard", (75, 5, 130, 50)), ("arcanist", (75, 5, 130, 50)), ("ranger", (75, 5, 130, 50))],
    [("paladin", (75, 5, 130, 50)), ("voidblade", (75, 5, 130, 50)), ("chronomancer", (75, 5, 130, 50))],
    [("gunslinger", (75, 5, 130, 50)), ("necromancer", (75, 5, 130, 50)), ("stormcaller", (75, 5, 130, 50))]
]

col_w = 1024 / 3.0 # 341.33
row_h = 682 / 3.0  # 227.33

portrait_gaps = {
    "vanguard": 131,
    "arcanist": 132,
    "ranger": 136,
    "paladin": 132,
    "voidblade": 135,
    "chronomancer": 140,
    "gunslinger": 129,
    "necromancer": 138,
    "stormcaller": 131,
}

row_gaps = {
    "vanguard": 146,
    "arcanist": 145,
    "ranger": 147,
    "paladin": 144,
    "voidblade": 145,
    "chronomancer": 142,
    "gunslinger": 142,
    "necromancer": 142,
    "stormcaller": 140,
}

for r in range(3):
    for c in range(3):
        cls_name, icon_rel = classes_grid[r][c]
        print(f"Processing {cls_name}...")
        cx = int(c * col_w)
        cy = int(r * row_h)
        p_gap = portrait_gaps[cls_name]
        r_gap = row_gaps[cls_name]

        # 1. Full Portrait (left of cell)
        portrait_crop = crop_and_clean(
            img_classes,
            (cx, cy + 45, cx + p_gap, cy + 227),
            remove_bg=True
        )
        portrait_crop.save(os.path.join(OUTPUT_CHAR_DIR, f"hero_{cls_name}.png"))
        print(f"  hero_{cls_name} portrait saved: {portrait_crop.size}")

        # 2. Crest Icon (header of cell)
        crest_crop = crop_and_clean(
            img_classes,
            (cx + 70, cy + 5, cx + 135, cy + 50),
            remove_bg=True
        )
        crest_crop.save(os.path.join(OUTPUT_ICONS_DIR, f"crest_{cls_name}.png"))

        # 3. Gameplay frames
        sprites_top_w = 341 - p_gap
        sub_w = sprites_top_w / 4.0

        # idle0 (Front)
        idle0 = crop_and_clean(
            img_classes,
            (cx + p_gap, cy + 65, cx + p_gap + int(sub_w * 1.1), cy + r_gap),
            remove_bg=True
        )
        idle0.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_idle0.png"))

        # idle1 (3/4 Front)
        idle1 = crop_and_clean(
            img_classes,
            (cx + p_gap + int(sub_w * 0.9), cy + 65, cx + p_gap + int(sub_w * 2.1), cy + r_gap),
            remove_bg=True
        )
        idle1.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_idle1.png"))

        # walk0 (Back)
        walk0 = crop_and_clean(
            img_classes,
            (cx + p_gap + int(sub_w * 1.9), cy + 65, cx + p_gap + int(sub_w * 3.1), cy + r_gap),
            remove_bg=True
        )
        walk0.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_walk0.png"))

        # walk1 (Side)
        walk1 = crop_and_clean(
            img_classes,
            (cx + p_gap + int(sub_w * 2.9), cy + 65, cx + 341, cy + r_gap),
            remove_bg=True
        )
        walk1.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_walk1.png"))

        # Attack (Strike with VFX - middle of bottom row)
        attack = crop_and_clean(
            img_classes,
            (cx + p_gap + int(sprites_top_w * 0.22), cy + r_gap - 5, cx + p_gap + int(sprites_top_w * 0.78), cy + 227),
            remove_bg=True
        )
        attack.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_attack.png"))

        # Downed (KO pose - right of bottom row)
        downed = crop_and_clean(
            img_classes,
            (cx + p_gap + int(sprites_top_w * 0.70), cy + r_gap + 10, cx + 341, cy + 227),
            remove_bg=True
        )
        downed.save(os.path.join(OUTPUT_FRAMES_DIR, f"hero_{cls_name}_downed.png"))
        print(f"  hero_{cls_name} frames saved!")

print("\nAll 10 classes (Adventurer + 9 specializations) processed and saved successfully!")
