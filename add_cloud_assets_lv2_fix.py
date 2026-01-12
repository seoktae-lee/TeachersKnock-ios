
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

# ONLY PROCESSING LEVEL 2
source_files = {
    2: "uploaded_image_1_1768201352122.jpg",
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
    
    # Boundary seed
    for x in range(width):
        queue.append((x, 0)); bg_pixels[x,0] = 255
        queue.append((x, height-1)); bg_pixels[x, height-1] = 255
    for y in range(height):
        queue.append((0, y)); bg_pixels[0, y] = 255
        queue.append((width-1, y)); bg_pixels[width-1, y] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in shifts:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if bg_pixels[nx,ny] == 0:
                    if pixels[nx,ny] == 0:
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

def process_lv2_precision(img):
    print("  Strategy: V10 Precision (Stricter Outline Stop)")
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    queue = deque()
    # Seed corners
    seed_points = [
        (0,0), (width-1,0), (0,height-1), (width-1,height-1),
        (width//2,0), (width//2,height-1), (0,height//2), (width-1,height//2) 
    ]
    for x,y in seed_points:
        queue.append((x,y))
        mask_pixels[x,y] = 255
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    visited = set(seed_points)
    
    while queue:
        cx, cy = queue.popleft()
        
        for dx, dy in shifts:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if mask_pixels[nx,ny] == 0:
                    # Current candidate pixel
                    r,g,b = pixels[nx,ny]
                    h,s,v = rgb_to_hsv(r,g,b)
                    
                    is_stop_pixel = False
                    
                    # 1. STOP if True Black Outline (Character Edge)
                    # V < 0.25 (Dark)
                    # Previous was 0.6, which stopped on shadows!
                    if v < 0.3: is_stop_pixel = True
                    
                    # 2. STOP if High Color (Character Body)
                    # S > 0.08 
                    if s > 0.08: is_stop_pixel = True
                    
                    # 3. SAFETY: If it's pure white, run through it! (It's background halo)
                    # But prevent running into white head interior?
                    # White Head Interior will be protected by the Black Outline surrounding it.
                    # We assume the user is correct that there is a contour.
                    
                    # Also check color difference from neighbor to handle gradients gracefully?
                    # No, strict threshold is sharper for "cutout".
                    
                    if not is_stop_pixel:
                        # Continue eating background
                        mask_pixels[nx,ny] = 255
                        if (nx,ny) not in visited:
                            visited.add((nx,ny))
                            queue.append((nx,ny))
                        
    # Invert (255=Object)
    alpha = Image.eval(mask, lambda x: 0 if x==255 else 255)
    
    # Fill internal holes (Eyes, etc.)
    alpha = fill_holes(alpha)
    
    # ERODE to remove any "White Pixel" fringe remaining at the stopping point
    # V8 used 7. Let's stick with a healthy 3-5. 
    # Use 4.
    alpha = alpha.filter(ImageFilter.MinFilter(5))
    
    return alpha

def process_file(level, source_filename):
    print(f"Processing Level {level}...")
    path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(path): return
    
    try:
        img = Image.open(path)
        mask = process_lv2_precision(img)
        
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
        process_file(lv, fn)
