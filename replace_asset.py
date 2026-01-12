
import os
from PIL import Image

source_path = "/Users/leeseoktae/.gemini/antigravity/brain/e4cccea5-2d22-4a9d-9aa6-49a97ca1dbd5/uploaded_image_1768214926793.jpg"
target_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"

if os.path.exists(source_path):
    img = Image.open(source_path)
    img.save(target_path, "PNG")
    print(f"Converted and saved to {target_path}")
else:
    print(f"Source file not found: {source_path}")
