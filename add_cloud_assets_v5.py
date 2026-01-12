
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
    6: "uploaded_image_1768196592838.jpg"
}

def rgb_to_hsv(r, g, b):
    # Manual conversion because colorsys might behave differently or we want control
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
    """
    Fills internal holes in a binary mask (0=Black/Hole, 255=White/Object).
    Algorithm:
    1. Floodfill from the border (0,0) assuming it's background.
    2. Any black pixel NOT reached by the floodfill is an INTERNAL hole => Turn it White.
    """
    width, height = mask_img.size
    pixels = mask_img.load()
    
    # 1. Create a "Background Mask" initialized to 0
    bg_mask = Image.new('L', mask_img.size, 0)
    bg_pixels = bg_mask.load()
    
    queue = deque()
    
    # Seed from edges (assuming the object doesn't touch ALL edges completely)
    # We'll seed the entire border frame to be safe.
    for x in range(width):
        if pixels[x, 0] == 0: queue.append((x, 0)); bg_pixels[x, 0] = 255
        if pixels[x, height-1] == 0: queue.append((x, height-1)); bg_pixels[x, height-1] = 255
    for y in range(height):
        if pixels[0, y] == 0: queue.append((0, y)); bg_pixels[0, y] = 255
        if pixels[width-1, y] == 0: queue.append((width-1, y)); bg_pixels[width-1, y] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    
    while queue:
        cx, cy = queue.popleft()
        
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                if bg_pixels[nx, ny] == 0: # Not visited
                    if pixels[nx, ny] == 0: # It's Black in the original mask (Background candidate)
                        bg_pixels[nx, ny] = 255 # Mark as External Background
                        queue.append((nx, ny))
                        
    # Now:
    # bg_pixels=255 -> External Background
    # bg_pixels=0 -> Object OR Internal Hole
    
    # We want final mask where 255=Object (including filled holes)
    # So if bg_pixels is 0, it is Object.
    
    filled_mask = Image.new('L', mask_img.size)
    filled_pixels = filled_mask.load()
    
    for y in range(height):
        for x in range(width):
            if bg_pixels[x, y] == 0:
                filled_pixels[x, y] = 255 # Object (filled)
            else:
                filled_pixels[x, y] = 0 # Background
                
    return filled_mask

def process_dark_bg_hsv(img):
    """HSV Strategy for Dark Backgrounds (Lv 1, 4, 5, 6?)"""
    print("  Mode: Dark Background (HSV Segmentation)")
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            # Logic: Keep if Cyan/Blue OR Dark Outline
            is_object = False
            
            # Cloud Color (Cyan/Blue)
            if 140 <= h <= 270 and s > 0.05:
                is_object = True
            
            # Dark Outline (Black lines on Gray background)
            # Background is usually V ~ 0.4-0.6. Outlines ~< 0.25
            if v < 0.25:
                is_object = True
                
            if is_object:
                mask_pixels[x, y] = 255
                
    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(3)) # Despeckle
    mask = fill_holes(mask) # CRITICAL: Fill the white eyes/center
    mask = mask.filter(ImageFilter.MinFilter(3)) # Erode fringe
    
    return mask

def process_light_bg_floodfill(img):
    """Floodfill Strategy for Light Backgrounds (Lv 2, 3)"""
    print("  Mode: Light Background (Smart Floodfill)")
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0) # 0=Object (Initial), 255=Bg
    mask_pixels = mask.load()
    
    # Safe Zone for Head (Top-Center)
    safe_zone_center = (width // 2, int(height * 0.35))
    safe_zone_radius_sq = (width * 0.25) ** 2
    
    queue = deque()
    # Seed corners
    seeds = [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]
    for sx, sy in seeds:
        queue.append((sx, sy))
        mask_pixels[sx, sy] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    visited = set(seeds)
    tolerance = 40
    
    while queue:
        cx, cy = queue.popleft()
        curr_c = pixels[cx, cy]
        
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    # Check Safe Zone
                    dzx, dzy = nx - safe_zone_center[0], ny - safe_zone_center[1]
                    if (dzx*dzx + dzy*dzy) < safe_zone_radius_sq:
                        continue # Protected Head
                        
                    neigh_c = pixels[nx, ny]
                    d = abs(curr_c[0]-neigh_c[0]) + abs(curr_c[1]-neigh_c[1]) + abs(curr_c[2]-neigh_c[2])
                    
                    if d < tolerance:
                        mask_pixels[nx, ny] = 255
                        visited.add((nx, ny))
                        queue.append((nx, ny))
                        
    # Invert to Object Mask (255=Object)
    obj_mask = Image.eval(mask, lambda x: 0 if x == 255 else 255)
    
    # Fill Holes (Just in case)
    obj_mask = fill_holes(obj_mask)
    
    # Erode fringe
    obj_mask = obj_mask.filter(ImageFilter.MinFilter(3))
    
    return obj_mask

def apply_alpha(img, mask):
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
    return img

def process_file(level, source_filename):
    print(f"Processing Level {level}...")
    path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(path):
        print(f"  Missing: {path}")
        return
        
    try:
        img = Image.open(path)
        
        # 1. Auto-Detect Mode based on corners
        # Sample 4 corners
        w, h = img.size
        pixels = img.load()
        corners = [pixels[0,0], pixels[w-1,0], pixels[0, h-1], pixels[w-1, h-1]]
        avg_brightness = sum(sum(c) for c in corners) / (4*3) # 0-255
        
        mask = None
        if avg_brightness < 150:
            mask = process_dark_bg_hsv(img)
        else:
            mask = process_light_bg_floodfill(img)
            
        final_img = apply_alpha(img, mask)
        
        # Save
        imageset_name = f"{character_name}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path): os.makedirs(imageset_path)
        
        dest_filename = f"{character_name}_lv{level}.png"
        final_img.save(os.path.join(imageset_path, dest_filename), "PNG")
        
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")
        
    except Exception as e:
        print(f"  Failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    for lv, fn in source_files.items():
        process_file(lv, fn)
