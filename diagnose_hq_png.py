
import os
from PIL import Image

artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
filename = "uploaded_image_1768211867295.png"

path = os.path.join(artifacts_dir, filename)
if os.path.exists(path):
    img = Image.open(path)
    print(f"Format: {img.format}")
    print(f"Mode: {img.mode}")
    print(f"Size: {img.size}")
    
    # Check corner for transparency
    if img.mode == 'RGBA':
        print(f"Corner Pixel: {img.getpixel((0,0))}")
    else:
        print("No Alpha Channel")
else:
    print("File not found.")
