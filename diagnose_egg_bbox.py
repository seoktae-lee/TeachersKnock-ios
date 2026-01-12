
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
targets = ["stone_golem_lv1.imageset/stone_golem_lv1.png", "cloud_lv1.imageset/cloud_lv1.png"]

print("--- Reference Egg Content Sizes (BBox) ---")
for t in targets:
    path = os.path.join(assets_dir, t)
    if os.path.exists(path):
        img = Image.open(path)
        bbox = img.getbbox()
        if bbox:
            w = bbox[2] - bbox[0]
            h = bbox[3] - bbox[1]
            print(f"{t}: {w}x{h} (BBox)")
        else:
            print(f"{t}: Empty")
    else:
        print(f"{t}: Missing")
