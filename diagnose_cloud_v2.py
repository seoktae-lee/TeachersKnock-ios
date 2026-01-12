
import os
from PIL import Image

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/01899da8-7c92-459d-a1d5-c03ca7633216"
filenames = [
    "uploaded_image_2_1768196455460.jpg", # Lv3 (Head cut issue)
]

for fname in filenames:
    path = os.path.join(artifacts_dir, fname)
    if os.path.exists(path):
        try:
            img = Image.open(path)
            width, height = img.size
            img_rgb = img.convert("RGB")
            
            print(f"--- Diagnosing {fname} ---")
            
            # 1. Analyze Border Colors (Background)
            border_colors = set()
            for x in range(width):
                 border_colors.add(img_rgb.getpixel((x, 0)))
                 border_colors.add(img_rgb.getpixel((x, height-1)))
            for y in range(height):
                 border_colors.add(img_rgb.getpixel((0, y)))
                 border_colors.add(img_rgb.getpixel((width-1, y)))
                 
            print(f"Unique Border Colors Count: {len(border_colors)}")
            # Sort by brightness
            sorted_border = sorted(list(border_colors), key=lambda c: sum(c))
            print(f"Darkest Border Pixel: {sorted_border[0]}")
            print(f"Brightest Border Pixel: {sorted_border[-1]}")
            
            # 2. Analyze Center Colors (Object)
            center_x, center_y = width // 2, height // 2
            center_pixel = img_rgb.getpixel((center_x, center_y))
            print(f"Center Pixel: {center_pixel}")
            
            # Sample a vertical line through the middle to find the "Head"
            # Assuming head is near top
            print("Scanning vertical center line from top...")
            for y in range(height // 3): # Top 1/3
                px = img_rgb.getpixel((width//2, y))
                # Print if it changes significantly or is very bright
                if sum(px) > 600: # High brightness
                    print(f"Potential Head Pixel at ({width//2}, {y}): {px}")
                    break
                    
        except Exception as e:
            print(f"Error reading {fname}: {e}")
