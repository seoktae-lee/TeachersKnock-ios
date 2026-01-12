
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

def process_lv1_strict(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # OUTPUT MASK (0=Transparent, 255=Opaque)
    mask = Image.new('L', img.size, 255)
    mask_pixels = mask.load()
    
    # Floodfill Queue (Start from corners)
    queue = deque()
    seeds = [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]
    visited = set(seeds)
    for s in seeds:
        queue.append(s)
        mask_pixels[s] = 0
        
    shifts = [(-1,0), (1,0), (0,-1), (0,1)]
    
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in shifts:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    visited.add((nx, ny))
                    
                    r, g, b = pixels[nx, ny]
                    h, s, v = rgb_to_hsv(r, g, b)
                    
                    # STOP CONDITION (Is it the Egg?)
                    # Egg is Gold (S > 0.15) OR White Highlight (V > 0.9)
                    # We want to eat GRAY HALOS (S < 0.1, V ~ 0.4-0.6)
                    
                    is_egg = False
                    if s > 0.15: is_egg = True # Gold
                    if v > 0.90: is_egg = True # Sparkle
                    
                    if is_egg:
                        pass # Hit egg, stop.
                    else:
                        # Still Background
                        mask_pixels[nx, ny] = 0
                        queue.append((nx, ny))
    
    # EROSION
    # To remove the "contour line" mentioned by user
    mask = mask.filter(ImageFilter.MinFilter(5)) # Eat 5px into the egg 
    
    return mask

def resize_and_canvas(img, target_height=700, canvas_size=(1024, 1024)):
    # 1. Crop to Content
    bbox = img.getbbox()
    if not bbox: return img
    cropped = img.crop(bbox)
    
    # 2. Resize to Target Height (Aspect Ratio Preserved)
    aspect_ratio = cropped.width / cropped.height
    new_height = target_height
    new_width = int(new_height * aspect_ratio)
    
    resized = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # 3. Paste to Canvas
    final_img = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    paste_x = (canvas_size[0] - new_width) // 2
    paste_y = (canvas_size[1] - new_height) // 2
    final_img.paste(resized, (paste_x, paste_y))
    
    return final_img

print("Refining Lv 1 (Strict Size Matching)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask = process_lv1_strict(img)
    
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
    
    # Resize and place on 1024x1024 Canvas
    # Target Height 700 is a good middle ground between Cloud (671) and Golem (815)
    img = resize_and_canvas(img, target_height=700)
    
    # Save
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path} (Canvas: {img.size})")
else:
    print("File not found.")
