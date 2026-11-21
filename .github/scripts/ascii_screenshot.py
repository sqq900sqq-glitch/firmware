"""Print a coarse ASCII rendering of a game screenshot so CI logs show what is on screen."""
import sys
from collections import Counter
from PIL import Image

PALETTE = [
    (" ", (115, 191, 242)),  # sky
    ("~", (240, 245, 250)),  # clouds / white UI / goal pole
    ("#", (140, 92, 51)),    # ground
    ('"', (77, 179, 64)),    # grass
    ("=", (204, 128, 51)),   # platform
    ("-", (242, 191, 89)),   # platform top
    ("P", (217, 38, 38)),    # player
    ("P", (153, 13, 13)),    # player cap
    ("o", (255, 255, 0)),    # coin
    ("o", (255, 165, 0)),    # coin outline
    ("E", (115, 64, 25)),    # enemy
    ("k", (0, 0, 0)),        # black
]

def nearest(rgb):
    return min(PALETTE, key=lambda p: sum((a - b) ** 2 for a, b in zip(rgb, p[1])))[0]

def main(path, cols=110, rows=34):
    img = Image.open(path).convert("RGB")
    if img.height > img.width:
        img = img.rotate(90, expand=True)
    w, h = img.size
    px = img.load()
    print(f"--- {path} ({w}x{h}) ---")
    for r in range(rows):
        line = []
        for c in range(cols):
            counts = Counter()
            for sy in range(4):
                for sx in range(4):
                    x = int((c + (sx + 0.5) / 4) * w / cols)
                    y = int((r + (sy + 0.5) / 4) * h / rows)
                    counts[nearest(px[min(x, w - 1), min(y, h - 1)])] += 1
            non_sky = [(ch, n) for ch, n in counts.most_common() if ch != " "]
            line.append(non_sky[0][0] if non_sky and non_sky[0][1] >= 3 else " ")
        print("|" + "".join(line) + "|")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
