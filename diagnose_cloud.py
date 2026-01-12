
import os
from PIL import Image

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/01899da8-7c92-459d-a1d5-c03ca7633216"
filenames = [
    "uploaded_image_0_1768196455460.jpg",
    "uploaded_image_1768196592838.jpg"
]

for fname in filenames:
    path = os.path.join(artifacts_dir, fname)
    if os.path.exists(path):
        try:
            img = Image.open(path)
            width, height = img.size
            
            # Sample corners
            corners = [
                (0, 0),
                (width-1, 0),
                (0, height-1),
                (width-1, height-1)
            ]
            
            print(f"--- Diagnosing {fname} ---")
            print(f"Mode: {img.mode}, Size: {width}x{height}")
            
            img_rgb = img.convert("RGB")
            
            for i, pos in enumerate(corners):
                color = img_rgb.getpixel(pos)
                print(f"Corner {i} {pos}: {color}")
                
            # Sample a few pixels near the corner
            near_corner = (10, 10)
            print(f"Near Corner {near_corner}: {img_rgb.getpixel(near_corner)}")
            
        except Exception as e:
            print(f"Error reading {fname}: {e}")
    else:
        print(f"File not found: {path}")
