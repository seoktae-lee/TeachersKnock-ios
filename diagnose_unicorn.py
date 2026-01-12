
import os
from PIL import Image
import colorsys

artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
files = [
    "uploaded_image_0_1768207151593.jpg",
    "uploaded_image_1_1768207151593.jpg",
    "uploaded_image_2_1768207151593.jpg",
    "uploaded_image_3_1768207151593.jpg",
    "uploaded_image_4_1768207151593.jpg"
]

def analyze_image(fn, idx):
    path = os.path.join(artifacts_dir, fn)
    if not os.path.exists(path):
        print(f"[{idx}] Missing: {fn}")
        return

    try:
        img = Image.open(path)
        img = img.convert("RGB")
        w, h = img.size
        
        # Sample center (Object)
        cx, cy = w//2, h//2
        center_pixel = img.getpixel((cx, cy))
        
        # Sample corner (Background)
        corner_pixel = img.getpixel((10, 10))
        
        print(f"[{idx}] {fn} | Size: {w}x{h}")
        print(f"    Center: {center_pixel}")
        print(f"    Corner: {corner_pixel}")
        
    except Exception as e:
        print(f"[{idx}] Error: {e}")

if __name__ == "__main__":
    print("--- Unicorn Image Diagnosis ---")
    for i, f in enumerate(files):
        analyze_image(f, i)
