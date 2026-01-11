
import os
import math
from PIL import Image

# Configuration
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"
targets = [2, 3, 4, 6]

def is_background(r, g, b):
    # Condition 1: Strict RGB Threshold
    # Any pixel where all channels are > 215 is likely part of the white gradient background
    if r > 215 and g > 215 and b > 215:
        return True

    # Condition 2: Color Distance from White
    # Helps remove "dirty white" or "shadow" pixels
    # Distance to (255, 255, 255)
    dist = math.sqrt((255-r)**2 + (255-g)**2 + (255-b)**2)
    # Threshold 60 approx corresponds to RGB(220, 220, 220)
    if dist < 60:
        return True
        
    return False

def polish_image(level):
    imageset_name = f"{character_name}_lv{level}.imageset"
    filename = f"{character_name}_lv{level}.png"
    filepath = os.path.join(assets_dir, imageset_name, filename)
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return

    img = Image.open(filepath).convert("RGBA")
    datas = img.getdata()
    new_data = []
    
    changed_count = 0
    
    for item in datas:
        r, g, b, a = item
        
        # Only check visible pixels
        if a > 0 and is_background(r, g, b):
             new_data.append((255, 255, 255, 0))
             changed_count += 1
        else:
             new_data.append(item)
             
    img.putdata(new_data)
    img.save(filepath, "PNG")
    print(f"Polished Level {level}: Removed {changed_count} pixels.")

# Execution
print("Starting final polish for Levels 2, 3, 4, 6...")
for level in targets:
    polish_image(level)
print("Polish complete.")
