
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
targets = ["stone_golem_lv1.imageset/stone_golem_lv1.png", "cloud_lv1.imageset/cloud_lv1.png"]

print("--- Reference Egg Sizes ---")
for t in targets:
    path = os.path.join(assets_dir, t)
    if os.path.exists(path):
        img = Image.open(path)
        print(f"{t}: {img.size}")
    else:
        print(f"{t}: Missing")
