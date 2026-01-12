
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
targets = [
    "stone_golem_lv1.imageset/stone_golem_lv1.png",
    "cloud_lv1.imageset/cloud_lv1.png",
    "unicorn_lv1.imageset/unicorn_lv1.png"
]

print(f"{'Image':<30} | {'Size':<15} | {'BBox (Content Area)':<30} | {'Content Size':<15}")
print("-" * 100)

for t in targets:
    path = os.path.join(assets_dir, t)
    name = t.split('/')[1]
    if os.path.exists(path):
        img = Image.open(path)
        bbox = img.getbbox()
        if bbox:
            content_width = bbox[2] - bbox[0]
            content_height = bbox[3] - bbox[1]
            content_size = f"{content_width}x{content_height}"
        else:
            content_size = "0x0"
        
        print(f"{name:<30} | {str(img.size):<15} | {str(bbox):<30} | {content_size:<15}")
    else:
        print(f"{name:<30} | Missing")
