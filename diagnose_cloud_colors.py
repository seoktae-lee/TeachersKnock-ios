
import os
from PIL import Image

artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
files = [
    "uploaded_image_0_1768201352122.jpg",
    "uploaded_image_1_1768201352122.jpg",
    "uploaded_image_2_1768201352122.jpg",
    "uploaded_image_3_1768201352122.jpg",
    "uploaded_image_4_1768201352122.jpg"
]

for f in files:
    path = os.path.join(artifacts_dir, f)
    if not os.path.exists(path):
        print(f"File not found: {f}")
        continue
        
    try:
        img = Image.open(path).convert("RGB")
        w, h = img.size
        print(f"--- {f} ({w}x{h}) ---")
        
        corners = [
            (0, 0), (w-1, 0), (0, h-1), (w-1, h-1),
            (w//2, 0), (w//2, h-1), (0, h//2), (w-1, h//2)
        ]
        
        print("Corners/Edges samples:")
        for x, y in corners:
            c = img.getpixel((x, y))
            print(f"  ({x}, {y}): {c}")
            
        center = img.getpixel((w//2, h//2))
        print(f"  Center ({w//2}, {h//2}): {center}")
        print("")
        
    except Exception as e:
        print(f"Error reading {f}: {e}")
