
import os
from PIL import Image

artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
filename = "uploaded_image_1768209742781.jpg"

path = os.path.join(artifacts_dir, filename)
if os.path.exists(path):
    img = Image.open(path)
    img = img.convert("RGB")
    print(f"New Lv 1 Image: {img.size}")
    print(f"Corner Pixel: {img.getpixel((10,10))}")
else:
    print("File not found.")
