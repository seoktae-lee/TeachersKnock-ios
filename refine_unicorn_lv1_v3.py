
import os
import sys
from collections import deque
from PIL import Image, ImageFilter

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
filename = "uploaded_image_0_1768207151593.jpg" # Level 1 Image
folder_prefix = "unicorn"
level = 1

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

def process_lv1_nuclear(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # "Nuclear" Thresholds
    # We only keep pixels that are UNQUESTIONABLY Gold or Sparkle.
    # Anything ambiguous dies.
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_egg = False
            
            # 1. Saturation Check (Gold)
            # Default gray is < 0.1. Previous script used 0.15.
            # Now using 0.25. If it's pale gold/dirty gold -> GONE.
            if s > 0.25: is_egg = True
            
            # 2. Value Check (Sparkles)
            # Must be pure white highlight.
            if v > 0.95: is_egg = True
            
            # 3. Brightness Floor
            # Even if it's saturated, if it's dark (shadow), it might be blending with BG.
            # Reject dark pixels at the edge.
            if v < 0.3: is_egg = False 
            
            if is_egg:
                mask_pixels[x, y] = 255
    
    # Cleanup
    # 1. Median to remove noise
    mask = mask.filter(ImageFilter.MedianFilter(5))
    
    # 2. Fill Holes (Because strict thresholds might make swiss cheese of the center)
    # We use floodfill from outside to define "Background", everything else is Egg.
    bg_mask = Image.new('L', img.size, 0)
    bg_px = bg_mask.load()
    queue = deque([(0,0), (width-1,0), (0,height-1), (width-1,height-1)])
    bg_px[0,0] = 255 # Visited
    
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if bg_px[nx,ny] == 0: # Not visited
                    # Use the strict mask we just made
                    if mask_pixels[nx,ny] == 0: # It is currently background
                        bg_px[nx,ny] = 255
                        queue.append((nx,ny))
    
    # Invert BG mask to get Filled Egg
    final_mask = Image.new('L', img.size, 0)
    fm_px = final_mask.load()
    for y in range(height):
        for x in range(width):
            if bg_px[x,y] == 0: # Not BG -> Egg
                fm_px[x,y] = 255
                
    # 3. Aggressive Erosion
    # Shave off 9 pixels from the edge to destroy any remaining halo.
    final_mask = final_mask.filter(ImageFilter.MinFilter(9))
    
    return final_mask

def resize_and_canvas(img, target_height=700, canvas_size=(1024, 1024)):
    bbox = img.getbbox()
    if not bbox: return img
    cropped = img.crop(bbox)
    
    aspect_ratio = cropped.width / cropped.height
    new_height = target_height
    new_width = int(new_height * aspect_ratio)
    
    resized = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    final_img = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    paste_x = (canvas_size[0] - new_width) // 2
    paste_y = (canvas_size[1] - new_height) // 2
    final_img.paste(resized, (paste_x, paste_y))
    
    return final_img

print("Refining Lv 1 (Nuclear Option)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask = process_lv1_nuclear(img)
    
    img = img.convert("RGBA")
    img_data = img.getdata()
    mask_data = mask.getdata()
    new_data = []
    
    for i in range(len(img_data)):
        if mask_data[i] == 0:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(img_data[i])
            
    img.putdata(new_data)
    img = resize_and_canvas(img, target_height=700)
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path}")
else:
    print("File not found.")
