
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
    bg_mask = Image.new('L', mask_img.size, 0) # 0=Unvisited/ObjectCandidate
    bg_pixels = bg_mask.load()
    queue = deque()
    
    # Seed corners
    for x in range(width):
        queue.append((x, 0)); bg_pixels[x,0] = 255
        queue.append((x, height-1)); bg_pixels[x, height-1] = 255
    for y in range(height):
        queue.append((0, y)); bg_pixels[0,y] = 255
        queue.append((width-1, y)); bg_pixels[width-1, y] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in shifts:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if bg_pixels[nx,ny] == 0:
                    # If original mask is black (0), it's background
                    if pixels[nx,ny] == 0:
                        bg_pixels[nx,ny] = 255
                        queue.append((nx,ny))
    
    # Invert: If bg_pixels is 0 (unreached), it is internal hole -> Make it White (255)
    filled_mask = Image.new('L', mask_img.size)
    filled_px = filled_mask.load()
    for y in range(height):
        for x in range(width):
            if bg_pixels[x,y] == 0:
                filled_px[x,y] = 255 # Hole filled
            else:
                filled_px[x,y] = 0 # Background
    return filled_mask

# --- STRATEGIES ---

def process_lv2_3_outline_stop(img):
    """
    Floodfill from border.
    Stop ONLY when hitting a Dark Pixel (Outline) or High Saturation (Body).
    Ignores gradients in white. Effectively eats white halos.
    """
    print("  Strategy: Outline Stop Floodfill")
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # 0 = Object, 255 = Background
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    queue = deque()
    # Seed full border
    for x in range(width):
        queue.append((x,0)); mask_pixels[x,0]=255
        queue.append((x,height-1)); mask_pixels[x,height-1]=255
    for y in range(height):
        queue.append((0,y)); mask_pixels[0,y]=255
        queue.append((width-1,y)); mask_pixels[width-1,y]=255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    visited = set() # Avoid re-queueing
    
    while queue:
        cx, cy = queue.popleft()
        if (cx,cy) in visited: continue
        visited.add((cx,cy))
        
        for dx, dy in shifts:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if mask_pixels[nx,ny] == 0:
                    # Check if this pixel is part of the Object (Outline or Body)
                    r,g,b = pixels[nx,ny]
                    h,s,v = rgb_to_hsv(r,g,b)
                    
                    is_object = False
                    
                    # 1. Dark Outline?
                    # White BG is V~1.0. Outline is usually V<0.5.
                    if v < 0.6: is_object = True 
                    
                    # 2. Blue Body?
                    if s > 0.05: is_object = True
                    
                    if not is_object:
                        # It is Light/White Background -> Eat it
                        mask_pixels[nx,ny] = 255
                        queue.append((nx,ny))
                        
    # Invert to Alpha Mask (255=Object)
    alpha = Image.eval(mask, lambda x: 0 if x==255 else 255)
    
    # Fill Holes (Eyes/Interior)
    alpha = fill_holes(alpha)
    
    # Smooth edges
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    
    return alpha

def process_lv6_strict_hsv(img):
    """
    Strict HSV.
    Must be Blue/Cyan OR Pitch Black. 
    Gray gaps are removed.
    """
    print("  Strategy: Strict HSV (No Gray)")
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    px_mask = mask.load()
    
    for y in range(height):
        for x in range(width):
            r,g,b = pixels[x,y]
            h,s,v = rgb_to_hsv(r,g,b)
            
            is_object = False
            
            # 1. Cloud (Cyan/Blue)
            # Require decent saturation to kill gray noise
            if 140 <= h <= 270 and s > 0.08:
                is_object = True
                
            # 2. Outline (Pitch Black)
            # User said: "Gap in clothes/wing". That gap is likely Shadow/Gray (V~0.2-0.4).
            # Outline itself is Black (V~0.0-0.15).
            if v < 0.12: # Very strict black
                is_object = True
                
            if is_object:
                px_mask[x,y] = 255
                
    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(3))
    mask = fill_holes(mask)
    # Aggressive erosion for the gap
    mask = mask.filter(ImageFilter.MinFilter(5))
    
    return mask

def process_file(level, source_filename):
    print(f"Processing Level {level}...")
    path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(path): return
    
    try:
        img = Image.open(path)
        mask = None
        
        if level in [2, 3]:
            mask = process_lv2_3_outline_stop(img)
        elif level == 6:
            mask = process_lv6_strict_hsv(img)
        else:
            print("  Skipping (Already detected perfect)")
            return
            
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
        if lv in [1, 4, 5]: continue
        process_file(lv, fn)
