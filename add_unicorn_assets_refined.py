
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
folder_prefix = "unicorn"

source_files = {
    1: "uploaded_image_0_1768207151593.jpg",
    2: "uploaded_image_1_1768207151593.jpg",
    3: "uploaded_image_2_1768207151593.jpg",
    4: "uploaded_image_3_1768207151593.jpg",
    5: "uploaded_image_4_1768207151593.jpg",
    6: "uploaded_image_1768207386631.jpg"
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

def crop_and_pad(img, padding=20):
    # Get bounding box of non-transparent pixels
    bbox = img.getbbox()
    if not bbox: return img
    
    cropped = img.crop(bbox)
    
    # Pad evenly
    new_width = cropped.width + padding * 2
    new_height = cropped.height + padding * 2
    
    padded = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    padded.paste(cropped, (padding, padding))
    
    return padded

def process_image(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # Ultra Precision Logic
    # Unicorn = Gold (Yellow/Orange) -> High Saturation OR High Brightness (White)
    # Background = Gray -> Low Saturation AND Mid Brightness
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_object = False
            
            # Rule 1: High Saturation (Gold/Yellow)
            # Stricter than before (0.1 -> 0.12) to catch gray halos
            if s > 0.12: 
                is_object = True
            
            # Rule 2: High Value (White Sparkles / Highlights)
            # Must be VERY bright to be a sparkle.
            if v > 0.90: is_object = True
            
            # Rule 3: Outline Check
            # Black outlines (V < 0.15) should be kept
            if v < 0.15: is_object = True
            
            if is_object:
                mask_pixels[x, y] = 255

    # Refinement Pipeline
    # 1. Median to remove pepper noise
    mask = mask.filter(ImageFilter.MedianFilter(3))
    
    # 2. Fill Holes (Critical for ensuring body is solid)
    mask = fill_holes(mask)
    
    # 3. Erosion (Remove Halo)
    # Increased strength (3 -> 5) for "Ultra Precision" requested by user
    mask = mask.filter(ImageFilter.MinFilter(5)) 
    
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
        
        # Step 4: Crop and Pad (Resize)
        img = crop_and_pad(img)
        
        imageset_name = f"{folder_prefix}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path): os.makedirs(imageset_path)
        
        dest_filename = f"{folder_prefix}_lv{level}.png"
        img.save(os.path.join(imageset_path, dest_filename), "PNG")
        
        # Contents.json is already likely correct, but overwrite to be safe
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path} (Size: {img.size})")
        
    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    for lv, fn in source_files.items():
        process_file(lv, fn)
