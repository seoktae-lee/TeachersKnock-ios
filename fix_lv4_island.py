
import os
from PIL import Image

# Configuration
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
target_level = 4
character_name = "stone_golem"

def fix_island_hole(image_path):
    if not os.path.exists(image_path):
        print(f"Error: File not found {image_path}")
        return

    img = Image.open(image_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    new_data = []
    
    # Threshold based on previous diagnosis (Background was ~208-210)
    # We use a slightly safer threshold to avoid eating into character details if possible
    # But high enough to catch the light gray.
    THRESHOLD = 200 
    
    changed_count = 0
    for item in datas:
        # item is (R, G, B, A)
        r, g, b, a = item
        
        # If the pixel is visible AND is light gray/white (Background color)
        if a > 0 and r > THRESHOLD and g > THRESHOLD and b > THRESHOLD:
            new_data.append((255, 255, 255, 0)) # Make Transparent
            changed_count += 1
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(image_path, "PNG")
    print(f"Processed Level {target_level}: {image_path}")
    print(f"Changed {changed_count} pixels to transparent.")

# Execution
imageset_name = f"{character_name}_lv{target_level}.imageset"
png_filename = f"{character_name}_lv{target_level}.png"
png_path = os.path.join(assets_dir, imageset_name, png_filename)

fix_island_hole(png_path)
