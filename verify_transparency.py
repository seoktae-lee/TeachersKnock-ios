
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

def verify_level(level):
    filename = f"{character_name}_lv{level}.png"
    path = os.path.join(assets_dir, f"{character_name}_lv{level}.imageset", filename)
    
    if not os.path.exists(path):
        print(f"[FAIL] Level {level}: File not found at {path}")
        return False
        
    try:
        img = Image.open(path)
        if img.mode != 'RGBA':
            print(f"[FAIL] Level {level}: Not RGBA (Mode: {img.mode})")
            return False
            
        width, height = img.size
        pixels = img.load()
        
        # Check Corners (Must be transparent)
        corners = [
            (0, 0), (width-1, 0), (0, height-1), (width-1, height-1)
        ]
        
        failed_corners = 0
        for x, y in corners:
            r, g, b, a = pixels[x, y]
            if a != 0:
                failed_corners += 1
                
        if failed_corners > 0:
            print(f"[WARN] Level {level}: {failed_corners}/4 corners are NOT transparent.")
        else:
            print(f"[PASS] Level {level}: Borders appear clean.")

        # Check Opacity Ratio
        total_pixels = width * height
        transparent_pixels = 0
        for y in range(height):
            for x in range(width):
                 if pixels[x, y][3] == 0:
                     transparent_pixels += 1
                     
        ratio = transparent_pixels / total_pixels
        print(f"       Transparency: {ratio*100:.1f}%")
        
        if ratio > 0.99:
             print("       [WARN] Image is almost empty!")
        if ratio < 0.10:
             print("       [WARN] Image is almost fully solid (Background might remain)!")
             
        return True

    except Exception as e:
        print(f"[ERR] Level {level}: {e}")
        return False

print("--- Verifying Cloud Assets ---")
for i in range(1, 6):
    verify_level(i)
