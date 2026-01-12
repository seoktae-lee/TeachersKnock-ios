
import os
import sys
from collections import deque
from PIL import Image, ImageFilter, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
filename = "uploaded_image_1768211599675.jpg" # NEW Image with Checkered BG
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

def super_smooth_mask(mask, upscale_factor=8, blur_radius=20):
    w, h = mask.size
    new_w, new_h = w * upscale_factor, h * upscale_factor
    big_mask = mask.resize((new_w, new_h), Image.Resampling.BICUBIC)
    big_mask = big_mask.filter(ImageFilter.GaussianBlur(blur_radius))
    
    fn = lambda x : 255 if x > 128 else 0
    big_mask = big_mask.convert('L').point(fn, mode='1')
    
    small_mask = big_mask.resize((w, h), Image.Resampling.LANCZOS).convert('L')
    return small_mask

def process_lv1_checkers(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # Thresholds for Checkered BG
    # BG is Gray: (104,104,104) -> S=0, V=0.4
    # Egg is Gold: S > 0.2
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            is_egg = False
            
            # 1. Saturation Check
            if s > 0.20: is_egg = True
            
            # 2. Value Check (Sparkles)
            if v > 0.90: is_egg = True
            
            # 3. Explicit Gray Checkered Removal
            # If Saturation is low (< 0.1) AND Value is Mid (~0.4-0.6), it's BG.
            if s < 0.1 and 0.3 < v < 0.7:
                is_egg = False
            
            if is_egg: mask_pixels[x, y] = 255
            
    # Cleanup
    mask = mask.filter(ImageFilter.MedianFilter(5))
    
    # Fill Holes
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
    
    # Erosion (Clean edge)
    final_mask = final_mask.filter(ImageFilter.MinFilter(5))
    
    # Super Smooth
    final_mask = super_smooth_mask(final_mask)
    
    return final_mask

def resize_and_canvas_padded(img, mask, target_height=710, canvas_size=(1024, 1024)):
    rgba_img = img.convert("RGBA")
    data = rgba_img.getdata()
    mask_data = mask.getdata()
    new_data = []
    
    for i in range(len(data)):
        alpha = mask_data[i]
        if alpha > 0:
            r, g, b, a = data[i]
            # Multiply original alpha by mask alpha
            new_a = int(a * (alpha / 255.0))
            new_data.append((r, g, b, new_a))
        else:
            new_data.append((0, 0, 0, 0))
    rgba_img.putdata(new_data)
    
    bbox = rgba_img.getbbox()
    if not bbox: return rgba_img
    cropped = rgba_img.crop(bbox)
    
    aspect_ratio = cropped.width / cropped.height
    new_height = target_height
    new_width = int(new_height * aspect_ratio)
    
    resized = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    final_img = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    paste_x = (canvas_size[0] - new_width) // 2
    paste_y = (canvas_size[1] - new_height) // 2
    final_img.paste(resized, (paste_x, paste_y))
    
    return final_img

print("Refining Lv 1 (V12: Checkers Removal)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask = process_lv1_checkers(img)
    
    img = resize_and_canvas_padded(img, mask, target_height=710)
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path}")
else:
    print("File not found.")
