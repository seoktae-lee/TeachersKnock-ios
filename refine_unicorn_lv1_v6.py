
import os
import sys
from collections import deque
from PIL import Image, ImageFilter, ImageChops, ImageOps

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

def smooth_mask(mask, upscale_factor=4, blur_radius=10):
    # 1. Upscale
    w, h = mask.size
    new_w, new_h = w * upscale_factor, h * upscale_factor
    # Using Nearest to keep edges sharp initially, or Bilinear? 
    # Let's use Bilinear to start soft
    big_mask = mask.resize((new_w, new_h), Image.Resampling.BILINEAR)
    
    # 2. Gaussian Blur (Smoothing)
    # Radius depends on upscale factor. 10px on 4x ~ 2.5px on original.
    big_mask = big_mask.filter(ImageFilter.GaussianBlur(blur_radius))
    
    # 3. Threshold (Re-binarize)
    # 128 is mid-point.
    # To mimic erosion/dilation, we can shift this threshold.
    # > 128 means we cut into the blur (erosion-ish). 
    threshold = 128
    fn = lambda x : 255 if x > threshold else 0
    big_mask = big_mask.convert('L').point(fn, mode='1')
    
    # 4. Downscale
    # Use LANCZOS for best quality, it produces grayscale edges (antialiasing)
    # But we want a sharp mask for extraction? 
    # Actually, for the outline generation, we want a binary mask.
    # Let's stick to binary for the shape.
    small_mask = big_mask.resize((w, h), Image.Resampling.LANCZOS).convert('L')
    
    # Re-binarize final result for crisp edge
    small_mask = small_mask.point(lambda x: 255 if x > 128 else 0)
    
    return small_mask

def process_lv1_smooth_outline(img):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0)
    mask_pixels = mask.load()
    
    # 1. Nuclear Thresholding
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            is_egg = False
            if s > 0.25: is_egg = True
            if v > 0.95: is_egg = True
            if v < 0.3: is_egg = False 
            if is_egg: mask_pixels[x, y] = 255
    
    # Initial cleanup
    mask = mask.filter(ImageFilter.MedianFilter(5))
    
    # 2. Fill Holes (Inner Solid)
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

    # 3. Erosion (Before smoothing, to make sure we are inside)
    final_mask = final_mask.filter(ImageFilter.MinFilter(7))
    
    # --- NEW: SMOOTHING ---
    # Smooth the jagged erosion result
    smoothed_mask = smooth_mask(final_mask, upscale_factor=4, blur_radius=15)
    
    # --- Outline Generation on Smoothed Mask ---
    # Small Dilation for the outline width
    # Radius 3 on original scale
    dilated_mask = smoothed_mask.filter(ImageFilter.MaxFilter(5))
    
    # Subtract to get ring
    outline_mask = ImageChops.difference(dilated_mask, smoothed_mask)
    
    # Smooth the outline mask itself slightly? No, the base shapes are smooth.
    
    return smoothed_mask, outline_mask

def resize_and_canvas_with_outline(img, mask, outline_mask, target_height=700, canvas_size=(1024, 1024)):
    # Create RGBA Image
    width, height = img.size
    rgba_img = img.convert("RGBA")
    data = rgba_img.getdata()
    mask_data = mask.getdata()
    outline_data = outline_mask.getdata()
    
    new_data = []
    
    # Contour Color: SOLID GOLD
    outline_r, outline_g, outline_b, outline_a = 255, 215, 0, 255
    
    for i in range(len(data)):
        if mask_data[i] > 0:
            new_data.append(data[i])
        elif outline_data[i] > 0:
            new_data.append((outline_r, outline_g, outline_b, outline_a))
        else:
            new_data.append((0, 0, 0, 0))
            
    rgba_img.putdata(new_data)
    
    # Resize Logic
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

print("Refining Lv 1 (V6: SMOOTH Gold Line)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    mask, outline_mask = process_lv1_smooth_outline(img)
    
    img = resize_and_canvas_with_outline(img, mask, outline_mask, target_height=700)
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path}")
else:
    print("File not found.")
