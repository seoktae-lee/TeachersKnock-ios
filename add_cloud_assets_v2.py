
import os
import sys
import json
from collections import deque
from PIL import Image, ImageFilter, ImageDraw, ImageChops

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

# Map level to source file
source_files = {
    1: "uploaded_image_0_1768201352122.jpg",
    2: "uploaded_image_1_1768201352122.jpg",
    3: "uploaded_image_2_1768201352122.jpg",
    4: "uploaded_image_3_1768201352122.jpg",
    5: "uploaded_image_4_1768201352122.jpg"
}

def get_border_colors(img):
    """Samples 8 points on the border to find likely background colors."""
    width, height = img.size
    pixels = img.load()
    
    samples = [
        pixels[0, 0], pixels[width-1, 0], 
        pixels[0, height-1], pixels[width-1, height-1],
        pixels[width//2, 0], pixels[width//2, height-1],
        pixels[0, height//2], pixels[width-1, height//2]
    ]
    return samples

def color_diff(c1, c2):
    return abs(c1[0]-c2[0]) + abs(c1[1]-c2[1]) + abs(c1[2]-c2[2])

def is_colorful(c, hue_threshold=10):
    """Returns True if the pixel is colorful (high saturation), likely the cloud."""
    r, g, b = c
    diff = max(abs(r-g), abs(g-b), abs(r-b))
    return diff > hue_threshold

def remove_background_adaptive(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # 1. Learn Background from Borders
    bg_samples = get_border_colors(img)
    
    # Calculate average background brightness to check if it's dark
    avg_bg_brightness = sum(sum(c) for c in bg_samples) / (len(bg_samples) * 3)
    is_dark_background = avg_bg_brightness < 150
    print(f"  > Level {level}: Avg BG Brightness={avg_bg_brightness:.1f}, Dark Mode={is_dark_background}")

    mask = Image.new('L', img.size, 0) # 0 = Object, 255 = Background
    mask_pixels = mask.load()
    
    # 2. Geometric Protection (Head Zone for Lv 2, 3)
    # The head is white, which matches white backgrounds. Spatial lock is needed.
    has_safe_zone = False
    safe_zone_center = (width // 2, int(height * 0.35))
    safe_zone_radius_sq = (width * 0.20) ** 2
    
    if level in [2, 3]:
        has_safe_zone = True

    # 3. Floodfill
    queue = deque()
    
    # Seed borders
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height-1))
        mask_pixels[x, 0] = 255
        mask_pixels[x, height-1] = 255
    for y in range(height):
        queue.append((0, y))
        queue.append((width-1, y))
        mask_pixels[0, y] = 255
        mask_pixels[width-1, y] = 255
        
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    visited = set()
    
    # Tolerance for background variations (gradient/shadows)
    # Stricter tolerance for dark backgrounds to avoid eating into dark outlines
    color_tolerance = 40 if is_dark_background else 60

    while queue:
        x, y = queue.popleft()
        
        if (x, y) in visited: continue
        visited.add((x, y))
        
        curr_color = pixels[x, y]
        
        for dx, dy in offsets:
            nx, ny = x + dx, y + dy
            
            if 0 <= nx < width and 0 <= ny < height:
                if mask_pixels[nx, ny] == 0: # Not yet marked as background
                    neighbor_color = pixels[nx, ny]
                    
                    # --- CHECKS ---
                    
                    # 1. Safe Zone Protection (Absolute Spatial Lock)
                    if has_safe_zone:
                        dist_sq = (nx - safe_zone_center[0])**2 + (ny - safe_zone_center[1])**2
                        if dist_sq < safe_zone_radius_sq:
                            continue # Don't touch head
                    
                    # 2. Is it colorful? (The Cloud is Blue/Cyan)
                    if is_colorful(neighbor_color):
                        continue # Hit the object
                        
                    # 3. Is it similar to the current background pixel?
                    # This handles gradients naturally.
                    diff = color_diff(curr_color, neighbor_color)
                    if diff < color_tolerance:
                        # It flows from the confirmed background pixel.
                        mask_pixels[nx, ny] = 255
                        queue.append((nx, ny))
                    
                    # 4. Fallback: Compare against global border samples?
                    # (Optional, but neighbor diffusion usually works best for gradients)

    # 4. Refine Mask
    # Invert: 255 now means Object, 0 means Background
    alpha_mask = Image.eval(mask, lambda x: 0 if x == 255 else 255)
    
    # 5. Erosion (Remove Halos)
    # Stronger erosion for dark backgrounds because the "white" halo is very visible against dark
    erosion_size = 5 if is_dark_background else 3
    final_alpha = alpha_mask.filter(ImageFilter.MinFilter(erosion_size))
    
    # 6. Apply to Image
    img = img.convert("RGBA")
    new_data = []
    
    mask_data = final_alpha.getdata()
    img_data = img.getdata()
    
    for i, item in enumerate(img_data):
        if mask_data[i] == 0:
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    return img

def process_file(level, source_filename):
    print(f"Processing Level {level} ({source_filename})...")
    
    source_path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(source_path):
        print(f"  Error: Source not found {source_path}")
        return

    try:
        img = Image.open(source_path)
        img_final = remove_background_adaptive(img, level)
        
        # Save to Assets
        imageset_name = f"{character_name}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        
        if not os.path.exists(imageset_path):
            os.makedirs(imageset_path)
            
        dest_filename = f"{character_name}_lv{level}.png"
        dest_path = os.path.join(imageset_path, dest_filename)
        
        img_final.save(dest_path, "PNG")
        
        # Contents.json
        contents = {
            "images": [
                {
                    "filename": dest_filename,
                    "idiom": "universal"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")

    except Exception as e:
        print(f"  Failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if not os.path.exists(assets_dir):
        print("Error: Assets directory not found.")
    else:
        for level, filename in source_files.items():
            process_file(level, filename)
