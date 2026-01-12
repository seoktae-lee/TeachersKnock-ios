
import os
from PIL import Image

artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
filename = "uploaded_image_1768211599675.jpg"

path = os.path.join(artifacts_dir, filename)
if os.path.exists(path):
    img = Image.open(path)
    img = img.convert("RGB")
    print(f"Image Size: {img.size}")
    
    # Sample corners to find background colors
    samples = [
        (10, 10), 
        (20, 10), 
        (10, 20),
        (50, 50)
    ]
    print("--- Background Samples ---")
    for x, y in samples:
        print(f"Pixel({x},{y}): {img.getpixel((x,y))}")
else:
    print("File not found.")
