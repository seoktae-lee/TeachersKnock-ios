
import os
from PIL import Image, ImageFilter

# Configuration
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"
targets = [2, 4, 6]

def erode_and_clean(level):
    imageset_name = f"{character_name}_lv{level}.imageset"
    filename = f"{character_name}_lv{level}.png"
    filepath = os.path.join(assets_dir, imageset_name, filename)
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return

    img = Image.open(filepath).convert("RGBA")
    
    # 1. Separate Channels
    r, g, b, a = img.split()
    
    # 2. Erode Alpha Channel (Shrink the shape by ~1 pixel)
    # MinFilter(3) looks at 3x3 area and takes min value. 
    # If any neighbor is 0 (transparent), the pixel becomes 0.
    eroded_a = a.filter(ImageFilter.MinFilter(3))
    
    # 3. Create new image with eroded alpha
    img_eroded = Image.merge("RGBA", (r, g, b, eroded_a))
    
    # 4. Strict Edge Cleaning (Pixel Access)
    # Even after erosion, some "white" pixels might remain if the halo was thick.
    # We check for semi-transparent pixels that are LIGHT.
    datas = img_eroded.getdata()
    new_data = []
    
    count_removed = 0
    for item in datas:
        cur_r, cur_g, cur_b, cur_a = item
        
        # If it's visible...
        if cur_a > 0:
            # Check brightness
            brightness = (cur_r + cur_g + cur_b) // 3
            
            # If it's semi-transparent (edge) AND bright (halo)
            # OR if it's very bright (background leftover)
            is_halo = (cur_a < 255 and brightness > 150)
            is_background = (brightness > 210)
            
            if is_halo or is_background:
                new_data.append((255, 255, 255, 0))
                count_removed += 1
            else:
                new_data.append(item)
        else:
            new_data.append(item)
            
    img_eroded.putdata(new_data)
    img_eroded.save(filepath, "PNG")
    print(f"Processed Level {level}: Eroded edges & Removed {count_removed} halo pixels.")

# Execution
print("Starting Alpha Erosion & Edge Cleaning...")
for level in targets:
    erode_and_clean(level)
print("Complete.")
