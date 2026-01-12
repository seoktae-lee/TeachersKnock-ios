
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops, ImageDraw

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

source_files = {
    1: "uploaded_image_0_1768201352122.jpg",
    2: "uploaded_image_1_1768201352122.jpg",
    3: "uploaded_image_2_1768201352122.jpg",
    4: "uploaded_image_3_1768201352122.jpg",
    5: "uploaded_image_4_1768201352122.jpg",
    6: "uploaded_image_1768196592838.jpg" # Added Level 6
}

def color_diff(c1, c2):
    return abs(c1[0]-c2[0]) + abs(c1[1]-c2[1]) + abs(c1[2]-c2[2])

def smart_floodfill(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # Creates a mask where 0=Object, 255=Background
    # We start initialized to 0 (Object).
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    queue = deque()
    
    # 1. Seeds from Border
    # We'll use all 4 corners and the middle of EDGES as seeds.
    seeds = [
        (0,0), (width-1, 0), (0, height-1), (width-1, height-1),
        (width//2, 0), (width//2, height-1), (0, height//2), (width-1, height//2)
    ]
    
    # 2. Safe Zone Protection (Critical for Lv 2, 3)
    # Don't let floodfill enter the "Head" area.
    # The head is roughly top-center.
    has_safe_zone = False
    if level in [2, 3, 6]: # Assuming Lv6 might also have light parts near top
        has_safe_zone = True
        safe_zone_center = (width // 2, int(height * 0.4))
        safe_zone_radius_sq = (width * 0.25) ** 2
    
    # Initialize Queue
    for sx, sy in seeds:
        queue.append((sx, sy))
        mask_pixels[sx, sy] = 255 # Mark as processed/background

    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    visited = set(seeds)
    
    # Standard Tolerance
    tolerance = 50 
    
    while queue:
        cx, cy = queue.popleft()
        current_color = pixels[cx, cy]
        
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    
                    # Safe Zone Check
                    if has_safe_zone:
                        dx_sz = nx - safe_zone_center[0]
                        dy_sz = ny - safe_zone_center[1]
                        if (dx_sz*dx_sz + dy_sz*dy_sz) < safe_zone_radius_sq:
                            continue # Blocked by Safe Zone

                    neighbor_color = pixels[nx, ny]
                    d = color_diff(current_color, neighbor_color)
                    
                    if d < tolerance:
                        mask_pixels[nx, ny] = 255 # It is background
                        visited.add((nx, ny))
                        queue.append((nx, ny))
                    else:
                        # Edge detected!
                        pass

    # 3. Post-Processing: Fill Holes
    # Any black pixel (0) that is fully surrounded by white (255) needs to stay 0.
    # But wait, our logic was 255=Background.
    # So any 0 (Object) surrounded by 0 (Object) is fine.
    # What about "Holes in the character"? The V3 HSV script caused that. 
    # Floodfill ONLY eats from the outside. So internal white parts are SAFE unless the floodfill leaked in.
    # If the Safe Zone worked, it shouldn't leak.
    
    # 4. Invert for Alpha: 255=Object, 0=Background
    alpha = Image.eval(mask, lambda x: 0 if x == 255 else 255)
    
    # 5. Remove "Dirty Fringe" (Erosion)
    # The user complained about "dirty background around lines".
    # We will erode the Alpha channel slightly.
    alpha = alpha.filter(ImageFilter.MinFilter(3)) # Erode 3px radius
    
    # 6. Apply Alpha
    img = img.convert("RGBA")
    new_data = []
    
    img_data = img.getdata()
    alpha_data = alpha.getdata()
    
    for i in range(len(img_data)):
        if alpha_data[i] == 0:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(img_data[i])
            
    img.putdata(new_data)
    return img

def process_file(level, source_filename):
    print(f"Processing Level {level} (Smart Floodfill + SafeZone)...")
    source_path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(source_path):
        print(f"  Error: Source not found {source_path}")
        return

    try:
        img = Image.open(source_path)
        img_final = smart_floodfill(img, level)
        
        imageset_name = f"{character_name}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path):
            os.makedirs(imageset_path)
            
        dest_filename = f"{character_name}_lv{level}.png"
        dest_path = os.path.join(imageset_path, dest_filename)
        img_final.save(dest_path, "PNG")
        
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")

    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    if not os.path.exists(assets_dir):
        print("Error: Assets directory not found.")
    else:
        for level, filename in source_files.items():
            process_file(level, filename)
