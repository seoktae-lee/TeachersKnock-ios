
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageChops

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

def crop_and_pad(img, padding=20):
    bbox = img.getbbox()
    if not bbox: return img
    cropped = img.crop(bbox)
    new_width = cropped.width + padding * 2
    new_height = cropped.height + padding * 2
    padded = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    padded.paste(cropped, (padding, padding))
    return padded

def process_lv1_aggressive(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # OUTPUT MASK (0=Transparent, 255=Opaque)
    # Initialize as all Opaque, we will "eat" away the background
    mask = Image.new('L', img.size, 255)
    mask_pixels = mask.load()
    
    # Floodfill Queue
    queue = deque()
    
    # Start from corners
    seeds = [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]
    visited = set(seeds)
    for s in seeds:
        queue.append(s)
        mask_pixels[s] = 0 # Mark as background
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    
    # STOP CONDITION: What is the "Egg"?
    # The Egg is Gold/Yellow/Bright.
    # The Background is Dark Gray.
    def is_egg_pixel(x, y):
        r, g, b = pixels[x, y]
        h, s, v = rgb_to_hsv(r, g, b)
        
        # Rule 1: High Saturation (Gold)
        # Gray background is usually S < 0.1
        # Let's be strict: Egg must be S > 0.15
        if s > 0.15: return True
        
        # Rule 2: Very Bright (White Sparkles)
        if v > 0.90: return True
        
        # Rule 3: Outline?
        # The prompt says "contour around the egg has background".
        # This means we might be stopping TOO EARLY (at the gray halo).
        # We should NOT stop at dark distinct outlines if they are grayish.
        # But we MUST stop at the character edge.
        # Let's rely mainly on Saturation.
        
        return False

    while queue:
        cx, cy = queue.popleft()
        
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    visited.add((nx, ny))
                    
                    # Check if we hit the Egg
                    if is_egg_pixel(nx, ny):
                        # HIT THE EGG! Stop floodfill here.
                        # This pixel remains Opaque (255)
                        pass
                    else:
                        # Still Background (Gray/Dark/Low Saturation)
                        mask_pixels[nx, ny] = 0 # Transparent
                        queue.append((nx, ny))
    
    # Post-Processing
    # 1. Fill holes inside the egg (just in case floodfill leaked slightly or internal gray spots)
    # Actually, floodfill from outside shouldn't create internal holes unless there's a path.
    # But strictly speaking, we just carved the outside.
    
    # 2. Erosion
    # User said "contour has background".
    # Floodfill stops exactly when it hits "S > 0.15".
    # If there is a "fading" edge, we might still have a fringe.
    # Let's apply a healthy Erosion.
    mask = mask.filter(ImageFilter.MinFilter(5))
    
    # 3. Smooth
    # mask = mask.filter(ImageFilter.GaussianBlur(1)) # Soften edge slightly? No, user wants crisp.
    
    return mask

print("Refining Lv 1 (Aggressive)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask = process_lv1_aggressive(img)
    
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
    
    # Auto-Crop
    img = crop_and_pad(img)
    
    # Save
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path}")
else:
    print("File not found.")
