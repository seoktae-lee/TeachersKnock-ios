
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "unicorn_guardian" # Internal name 'unicorn_guardian' or just 'unicorn'? User said "Type: unicorn".
# I'll use 'unicorn' for the folder names to match 'cloud', 'golem'.
folder_prefix = "unicorn"

source_files = {
    1: "uploaded_image_0_1768207151593.jpg",
    2: "uploaded_image_1_1768207151593.jpg",
    3: "uploaded_image_2_1768207151593.jpg",
    4: "uploaded_image_3_1768207151593.jpg",
    5: "uploaded_image_4_1768207151593.jpg",
    6: "uploaded_image_1768207386631.jpg" # Real Lv 6 Image
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
    
    # Seeds (Corners)
    seeds = [(0,0), (width-1,0), (0,height-1), (width-1,height-1)]
    for sx, sy in seeds:
        queue.append((sx, sy)); bg_pixels[sx,sy] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in shifts:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if bg_pixels[nx,ny] == 0:
                    if pixels[nx,ny] == 0: # Is Background
                        bg_pixels[nx,ny] = 255
                        queue.append((nx,ny))
                        
    filled_mask = Image.new('L', mask_img.size)
    filled_px = filled_mask.load()
    for y in range(height):
        for x in range(width):
            if bg_pixels[x,y] == 0:
                 filled_px[x,y] = 255
            else:
                 filled_px[x,y] = 0
    return filled_mask

def process_image(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # Color Logic for Unicorn (Gold/Yellow)
    # Background is Dark Gray: (108, 109, 103) -> H~80, S~0.05, V~0.4
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_object = False
            
            # 1. Saturation Check
            # Gray BG has S < 0.1. Gold has S > 0.15 usually.
            if s > 0.10: 
                is_object = True
            
            # 2. Value Extremes
            # Highlights (White sparkles) -> V > 0.9, S low.
            if v > 0.85: is_object = True
            
            # Outlines (Black) -> V < 0.2
            if v < 0.2: is_object = True
            
            # 3. Specific Color Check (Yellow/Orange)
            # Just incase some dark gold has low sat? 
            # Usually Gold is Orange-Yellow (H 30-60).
            
            if is_object:
                mask_pixels[x, y] = 255

    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = fill_holes(mask)
    mask = mask.filter(ImageFilter.MinFilter(3)) # Erode slightly
    
    return mask

def process_file(level, source_filename):
    print(f"Processing Level {level}...")
    path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(path): 
        print(f"Missing {path}")
        return
    
    try:
        img = Image.open(path)
        mask = process_image(img, level)
        
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
        
        imageset_name = f"{folder_prefix}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path): os.makedirs(imageset_path)
        
        dest_filename = f"{folder_prefix}_lv{level}.png"
        img.save(os.path.join(imageset_path, dest_filename), "PNG")
        
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")
        
    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    for lv, fn in source_files.items():
        process_file(lv, fn)
