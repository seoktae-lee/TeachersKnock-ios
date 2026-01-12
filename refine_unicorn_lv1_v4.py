
import os
import sys
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

def process_lv1_contour(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # 1. Nuclear Thresholding (Same as V3)
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            is_egg = False
            if s > 0.25: is_egg = True
            if v > 0.95: is_egg = True
            if v < 0.3: is_egg = False 
            if is_egg: mask_pixels[x, y] = 255
    
    mask = mask.filter(ImageFilter.MedianFilter(5))
    
    # 2. Fill Holes
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
            
    # 3. Erosion
    final_mask = final_mask.filter(ImageFilter.MinFilter(9))
    
    # --- NEW: Generate Contour ---
    # Dilate the mask to create a slightly larger shape
    dilated_mask = final_mask.filter(ImageFilter.MaxFilter(3))
    
    # Subtract original mask from dilated mask to get the "Outline Ring"
    # outline_mask = dilated_mask - final_mask
    outline_mask = ImageChops.difference(dilated_mask, final_mask)
    
    return final_mask, outline_mask

def resize_and_canvas_with_outline(img, mask, outline_mask, target_height=700, canvas_size=(1024, 1024)):
    # Create RGBA Image
    width, height = img.size
    rgba_img = img.convert("RGBA")
    data = rgba_img.getdata()
    mask_data = mask.getdata()
    outline_data = outline_mask.getdata()
    
    new_data = []
    
    # Contour Color: Dark Gold (Unicorn Theme)
    # R:120, G:90, B:20, A:100 (Semi-transparent)
    outline_r, outline_g, outline_b, outline_a = 120, 90, 20, 80 
    
    for i in range(len(data)):
        if mask_data[i] > 0:
            # Inside Egg: Use original pixel
            new_data.append(data[i])
        elif outline_data[i] > 0:
            # On Outline: Use Outline Color
            # Blend hint: we just output the solid outline color here
            new_data.append((outline_r, outline_g, outline_b, outline_a))
        else:
            # Transparent BG
            new_data.append((0, 0, 0, 0))
            
    rgba_img.putdata(new_data)
    
    # Resize Logic
    # We must crop the bbox of the OUTLINE layer now, because the image has grown by the outline.
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

print("Refining Lv 1 (V4: Faint Contour)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask, outline_mask = process_lv1_contour(img)
    
    # Combine and Resize
    img = resize_and_canvas_with_outline(img, mask, outline_mask, target_height=700)
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path}")
else:
    print("File not found.")
