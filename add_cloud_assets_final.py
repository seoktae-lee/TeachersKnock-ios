
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops

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
    6: "uploaded_image_1768196592838.jpg"
}

def rgb_to_hsv(r, g, b):
    r, g, b = r/255.0, g/255.0, b/255.0
    mx = max(r, g, b)
    mn = min(r, g, b)
    df = mx-mn
    if mx == mn: h = 0
    elif mx == r: h = (60 * ((g-b)/df) + 360) % 360
    elif mx == g: h = (60 * ((b-r)/df) + 120) % 360
    elif mx == b: h = (60 * ((r-g)/df) + 240) % 360
    s = 0 if mx == 0 else df/mx
    v = mx
    return h, s, v

def fill_holes(mask_img):
    width, height = mask_img.size
    pixels = mask_img.load()
    
    bg_mask = Image.new('L', mask_img.size, 0)
    bg_pixels = bg_mask.load()
    
    queue = deque()
    # Seed corners and edges
    seeds = []
    for x in range(width):
        seeds.append((x, 0))
        seeds.append((x, height-1))
    for y in range(height):
        seeds.append((0, y))
        seeds.append((width-1, y))
        
    for sx, sy in seeds:
         if pixels[sx, sy] == 0:
             queue.append((sx, sy))
             bg_pixels[sx, sy] = 255
             
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                if bg_pixels[nx, ny] == 0:
                    if pixels[nx, ny] == 0:
                        bg_pixels[nx, ny] = 255
                        queue.append((nx, ny))
                        
    filled_mask = Image.new('L', mask_img.size)
    filled_px = filled_mask.load()
    for y in range(height):
        for x in range(width):
            if bg_pixels[x, y] == 0:
                filled_px[x, y] = 255
            else:
                filled_px[x, y] = 0
    return filled_mask

def process_image(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # --- LEVEL SPECIFIC TUNING ---
    
    # 1. Safe Zone (Lv 2, 3)
    # User Fdbk: "Circular background remains around head" -> Need Tighter Radius.
    # Previous: width * 0.28 (~280px). 
    # Try: width * 0.19 (~190px). 
    has_safe_zone = level in [2, 3]
    safe_zone_center = (width // 2, int(height * 0.35))
    safe_zone_radius_sq = (width * 0.19) ** 2 
    
    # 2. Dark Outline / Tail Artifacts (Lv 4, 5, 6)
    # User Fdbk: "Tail has minute background", "Lv6 wing gap".
    # Cause: Dark shadows being detected as "Dark Outline" (Values < 0.25).
    # Fix: Stricter Dark Threshold (Values < 0.15).
    dark_outline_threshold = 0.15 # Was 0.25. Stricter.
    
    # 3. Cloud Saturation
    # Tuning to capture blue/cyan but ignore gray noise
    min_saturation = 0.08
    
    corners = [pixels[0,0], pixels[width-1,0], pixels[0, height-1], pixels[width-1, height-1]]
    avg_bg = sum(sum(c) for c in corners) / 12.0
    is_dark_bg = avg_bg < 150
    
    print(f"Level {level}: DarkBG={is_dark_bg}, SafeZone={has_safe_zone} (R={width*0.19:.0f})")
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_object = False
            
            # A. Cloud Color check
            if 140 <= h <= 270:
                 if is_dark_bg:
                     if s > 0.05: is_object = True
                 else:
                     if s > min_saturation: is_object = True
            
            # B. Dark Outline check (The primary culprit for artifacts)
            if v < dark_outline_threshold: 
                is_object = True
            
            # C. Safe Zone (Strict Head Lock)
            if has_safe_zone:
                dx = x - safe_zone_center[0]
                dy = y - safe_zone_center[1]
                if (dx*dx + dy*dy) < safe_zone_radius_sq:
                    is_object = True
                    
            if is_object:
                mask_pixels[x, y] = 255
                
    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(3)) # Despeckle
    mask = fill_holes(mask) # Fill Internal Holes
    
    # Erosion
    # User said Lv 4/5 had "minute" artifacts. Increased erosion slightly closer to edge?
    # Actually, shrinking the mask is safer.
    # Level 6 "Wing Gap": If it was an "Internal Hole" filled by fill_holes, it would be white.
    # If it was "Dark Shadow" detected by HSV, it would be white.
    # Stricter Dark Threshold (0.15) should kill shadow detection in the gap.
    
    mask = mask.filter(ImageFilter.MinFilter(3))
    
    return mask

def process_file(level, source_filename):
    # Lv 1 is perfect per user. Skip it or just copy? 
    # User said: "Level 1 is very clean. Pass as is."
    # We will replicate the V6 logic (which worked) or just skip to save time/risk.
    # But V7 logic changes might affect Lv1 (Dark Threshold). 
    # Since Lv1 worked with V6 (Threshold 0.25), changing to 0.15 might lose outline?
    # User said "Lv 1 is perfect". Let's USE V6 Logic ONLY for Lv1, or just skip if file exists?
    # To be safe, let's keep V6 logic settings for Lv1 specifically if needed, OR just trust 0.15 is fine.
    # Actually, Lv1 outline is very dark black. 0.15 should be fine. 
    # BUT, to be absolutely safe and "Pass as is", I will NOT touch Lv 1 if possible.
    # However, for consistency of the script, I will run it. 0.15 is very dark (black). Outlines are usually <0.1.
    
    print(f"Processing Level {level}...")
    path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(path): return
    
    # Logic Branch for reliability
    # If Lv=1, use V6 settings (known good)? No, V6 code is gone.
    # Let's trust V7.
    
    try:
        img = Image.open(path)
        mask = process_image(img, level)
        
        # Apply Alpha
        img = img.convert("RGBA")
        new_data = []
        img_data = img.getdata()
        mask_data = mask.getdata()
        for i in range(len(img_data)):
            if mask_data[i] == 0:
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(img_data[i])
        img.putdata(new_data)
        
        imageset_name = f"{character_name}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path): os.makedirs(imageset_path)
        
        dest_filename = f"{character_name}_lv{level}.png"
        img.save(os.path.join(imageset_path, dest_filename), "PNG")
        
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")
        
    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    for lv, fn in source_files.items():
        if lv == 1: 
             print("Skipping Level 1 (User confirmed perfect)")
             continue
        process_file(lv, fn)
