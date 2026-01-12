
import os
import sys
from collections import deque
from PIL import Image, ImageFilter, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
filename = "uploaded_image_1768209742781.jpg" # NEW Level 1 Image
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

def process_lv1_final_fix(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # "Zero Tolerance" Thresholds
    # Gold: S > 0.28 (Very rich gold only)
    # Brightness: V > 0.96 (Pure white only)
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_egg = False
            
            if s > 0.28: is_egg = True
            if v > 0.96: is_egg = True
            
            # Kill shadows absolutely
            if v < 0.35: is_egg = False 
            
            if is_egg:
                mask_pixels[x, y] = 255
    
    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(5))
    
    # Fill Holes (Inner Solid)
    bg_mask = Image.new('L', img.size, 0)
    bg_px = bg_mask.load()
    queue = deque([(0,0), (width-1,0), (0,height-1), (width-1,height-1)])
    bg_px[0,0] = 255
    
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = cx+dx, cy+dy
            if 0<=nx<width and 0<=ny<height:
                if bg_px[nx,ny] == 0:
                    if mask_pixels[nx,ny] == 0:
                        bg_px[nx,ny] = 255
                        queue.append((nx,ny))
    
    final_mask = Image.new('L', img.size, 0)
    fm_px = final_mask.load()
    for y in range(height):
        for x in range(width):
            if bg_px[x,y] == 0: fm_px[x,y] = 255
                
    # Erosion: 6px shave
    final_mask = final_mask.filter(ImageFilter.MinFilter(7))
    
    return final_mask

def resize_and_canvas_padded(img, mask, target_height=620, canvas_size=(1024, 1024)):
    # Create RGBA
    rgba_img = img.convert("RGBA")
    data = rgba_img.getdata()
    mask_data = mask.getdata()
    new_data = []
    
    for i in range(len(data)):
        if mask_data[i] == 255:
            new_data.append(data[i])
        else:
            new_data.append((0, 0, 0, 0))
    rgba_img.putdata(new_data)
    
    # Crop
    bbox = rgba_img.getbbox()
    if not bbox: return rgba_img
    cropped = rgba_img.crop(bbox)
    
    # Resize
    # Target Height 620 -> This is significantly smaller than 700 to address "too big"
    aspect_ratio = cropped.width / cropped.height
    new_height = target_height
    new_width = int(new_height * aspect_ratio)
    
    resized = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Paste
    final_img = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    paste_x = (canvas_size[0] - new_width) // 2
    paste_y = (canvas_size[1] - new_height) // 2
    final_img.paste(resized, (paste_x, paste_y))
    
    return final_img

print("Refining Lv 1 (V8: Final Size Fix & Clean)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask = process_lv1_final_fix(img)
    
    img = resize_and_canvas_padded(img, mask, target_height=620)
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path} (Size: {img.size})")
else:
    print("File not found.")
