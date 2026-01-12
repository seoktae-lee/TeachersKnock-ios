
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageDraw, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/01899da8-7c92-459d-a1d5-c03ca7633216"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

# Map level to source file (Batch 2 for 1-5, Batch 1 for 6)
source_files = {
    1: "uploaded_image_0_1768201352122.jpg",
    2: "uploaded_image_1_1768201352122.jpg",
    3: "uploaded_image_2_1768201352122.jpg",
    4: "uploaded_image_3_1768201352122.jpg",
    5: "uploaded_image_4_1768201352122.jpg",
    6: "uploaded_image_1768196592838.jpg"
}

def remove_background_v12(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # --- STRATEGY: SMART BORDER FLOODFILL ---
    # Start from border (Known Background).
    # Flood "inwards" as long as pixels look like "Gray/White Background".
    # STOP if pixels look like "Cloud Color" (Blue/Cyan/Dark Outline).
    # STOP if pixels are in "Geometry Protected Zone" (Head).
    
    mask = Image.new('L', img.size, 0) # 0 = Object (Preserve), 255 = Background (Remove)
    mask_pixels = mask.load()
    queue = deque()
    
    # 1. Define "Cloud Color" (Stop Condition)
    # The cloud is distinctly "Not Gray".
    def is_cloud_color(c):
        r, g, b = c
        diff = max(abs(r-g), abs(g-b), abs(r-b))
        
        # Cloud is Blue/Cyan (B > R, B > G)
        # Or just "Colorful" (Diff > Threshold)
        # Outline is Dark Blue/Gray.
        
        # Rule 1: High Saturation -> Cloud
        if diff > 10: return True
        
        # Rule 2: Dark Pixel -> Outline -> Cloud
        brightness = (r+g+b)//3
        if brightness < 180: return True # Dark outlines are part of cloud
        
        return False
        
    # 2. Geometric Protection (Head Zone)
    # For Lv 2, 3: The head is White (Low Sat, High Brightness).
    # It looks exactly like Background White.
    # We MUST protect it spatially.
    
    safe_zone_radius_sq = 0
    safe_zone_center = (0,0)
    has_safe_zone = False
    
    if level in [2, 3]:
        has_safe_zone = True
        safe_zone_center = (width // 2, int(height * 0.35))
        safe_zone_radius_sq = (width * 0.20) ** 2 # 20% radius protection
        
    # 3. Seed from Border
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height-1))
        mask_pixels[x, 0] = 255
        mask_pixels[x, height-1] = 255
    for y in range(height):
        queue.append((0, y))
        queue.append((width-1, y))
        mask_pixels[0, y] = 255
        mask_pixels[width-1, y] = 255
        
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    
    while queue:
        x, y = queue.popleft()
        
        for dx, dy in offsets:
            nx, ny = x + dx, y + dy
            
            if 0 <= nx < width and 0 <= ny < height:
                if mask_pixels[nx, ny] == 0:
                    current_c = pixels[nx, ny]
                    
                    # --- STOP LOGIC ---
                    
                    # 1. Is it Cloud Color?
                    if is_cloud_color(current_c): 
                        continue # Hit the object. Stop.
                        
                    # 2. Is it in Safe Zone? (Lv 2,3 Head Protection)
                    if has_safe_zone:
                        dist_sq = (nx - safe_zone_center[0])**2 + (ny - safe_zone_center[1])**2
                        if dist_sq < safe_zone_radius_sq:
                             # It is spatially inside the head.
                             # Even if it looks like background (White), PROTECT IT.
                             continue
                             
                    # If passed checks, it is Background.
                    mask_pixels[nx, ny] = 255
                    queue.append((nx, ny))
                    
    # At this point:
    # mask=255 -> Confirmed Background (Floodfilled from border)
    # mask=0   -> Object (Cloud + Outlines + Protected Head + Unreachable Gaps?)
    
    # Note: "Unreachable Gaps" (e.g. fully enclosed background holes) will remain 0 (Object).
    # But user complained about "Background in between", which implies gaps connected to outside.
    # The floodfill SHOULD have reached them.
    
    # 4. Invert Mask to Alpha (0=Bg, 255=Object)
    # Currently 255=Bg.
    
    # We want final Alpha: 255=Object.
    alpha_mask = Image.eval(mask, lambda x: 0 if x == 255 else 255)
    
    # 5. Erosion (Halo Removal)
    # User requested "Outline Clean Cut".
    # Erosion shaves pixels from the Object edge.
    
    erosion_size = 3
    if level == 1: erosion_size = 5 # Aggressive for Lv1
    
    final_alpha = alpha_mask.filter(ImageFilter.MinFilter(erosion_size))
    
    # --- COMPOSE ---
    img = img.convert("RGBA")
    new_data = []
    
    mask_data = final_alpha.getdata()
    img_data = img.getdata()
    
    for i, item in enumerate(img_data):
        if mask_data[i] == 0:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    return img

def process_file(level, source_filename):
    imageset_name = f"{character_name}_lv{level}.imageset"
    imageset_path = os.path.join(assets_dir, imageset_name)
    
    if not os.path.exists(imageset_path):
        os.makedirs(imageset_path)
    
    dest_filename = f"{character_name}_lv{level}.png"
    dest_path = os.path.join(imageset_path, dest_filename)
    
    source_path = os.path.join(artifacts_dir, source_filename)
    
    if not os.path.exists(source_path):
        print(f"Error: Source not found {source_path}")
        return

    print(f"Processing Level {level}...")
    try:
        img = Image.open(source_path)
        
        # v12: Smart Border Floodfill + Erosion
        img_final = remove_background_v12(img, level)
        
        img_final.save(dest_path, "PNG")
        
        contents = {
            "images": [
                {
                    "filename": dest_filename,
                    "idiom": "universal"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"Created {imageset_name}")
        
    except Exception as e:
        print(f"Failed to process {source_filename}: {e}")
        import traceback
        traceback.print_exc()

# Execution
if not os.path.exists(assets_dir):
    print(f"Error: Assets directory not found: {assets_dir}")
else:
    for level, filename in source_files.items():
        process_file(level, filename)
    print("Smart Border Floodfill complete.")
