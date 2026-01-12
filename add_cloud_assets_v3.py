
import os
import sys
import json
from PIL import Image, ImageFilter

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

source_files = {
    1: "uploaded_image_0_1768201352122.jpg",
    2: "uploaded_image_1_1768201352122.jpg",
    3: "uploaded_image_2_1768201352122.jpg",
    4: "uploaded_image_3_1768201352122.jpg",
    5: "uploaded_image_4_1768201352122.jpg"
}

def rgb_to_hsv(r, g, b):
    r, g, b = r/255.0, g/255.0, b/255.0
    mx = max(r, g, b)
    mn = min(r, g, b)
    df = mx-mn
    if mx == mn:
        h = 0
    elif mx == r:
        h = (60 * ((g-b)/df) + 360) % 360
    elif mx == g:
        h = (60 * ((b-r)/df) + 120) % 360
    elif mx == b:
        h = (60 * ((r-g)/df) + 240) % 360
    if mx == 0:
        s = 0
    else:
        s = df/mx
    v = mx
    return h, s, v # h[0-360], s[0-1], v[0-1]

def extract_cloud_hsv(img, level):
    img = img.convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    mask = Image.new('L', img.size, 0) # 0 = Background, 255 = Object
    mask_pixels = mask.load()
    
    # Safe Zone for White Head (Lv 2, 3)
    # The head is top-center.
    safe_zone_center = (width // 2, int(height * 0.35))
    safe_zone_radius_sq = (width * 0.25) ** 2
    has_safe_zone = level in [2, 3]
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            h, s, v = rgb_to_hsv(r, g, b)
            
            # --- KEEP LOGIC (What part of the image is the Cloud?) ---
            
            is_object = False
            
            # 1. Color: Cloud is Cyan/Blue
            # Hue range: roughly 140 (Green-Cyan) to 260 (Blue-Purple)
            # Saturation must be significant (> 0.10) to distinguish from gray background
            if 140 <= h <= 270 and s > 0.10:
                is_object = True
            
            # 2. Outline: Dark Lines
            # Backgrounds in Lv1,4,5 are around V=0.4 ~ 0.6.
            # Deep outlines are V < 0.25 (Very Dark)
            if v < 0.25:
                is_object = True
                
            # 3. White Head Protection (Lv 2, 3)
            # If it's White (Low Sat, High Val) AND in the spatial zone
            if has_safe_zone:
                if s < 0.10 and v > 0.80:
                     dist_sq = (x - safe_zone_center[0])**2 + (y - safe_zone_center[1])**2
                     if dist_sq < safe_zone_radius_sq:
                         is_object = True

            # 4. Special Case: Lv 1,4,5 Dark Background noise handling
            # If S < 0.10 (Gray) and not Dark Outline (V > 0.3), it is Background.
            # This implicitly handles the gray wall/desk.
            
            if is_object:
                mask_pixels[x, y] = 255
            else:
                mask_pixels[x, y] = 0
                
    # --- Cleanup ---
    
    # 1. Median Filter to remove "Salt and Pepper" noise (isolated pixels)
    mask = mask.filter(ImageFilter.MedianFilter(size=3))
    
    # 2. Remove small disconnected blobs (Scraps) - OPTIONAL
    # If the background has some "blue-ish" noise, it might remain.
    # For now, rely on Median Filter.
    
    # 3. Erosion to tighten edges (Remove halo)
    mask = mask.filter(ImageFilter.MinFilter(3))
    
    # 4. Apply Mask
    img = img.convert("RGBA")
    new_data = []
    mask_data = mask.getdata()
    img_data = img.getdata()
    
    for i, item in enumerate(img_data):
        if mask_data[i] == 0:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    return img

def process_file(level, source_filename):
    print(f"Processing Level {level} (HSV Strategy)...")
    source_path = os.path.join(artifacts_dir, source_filename)
    if not os.path.exists(source_path):
        print(f"  Error: Source not found {source_path}")
        return

    try:
        img = Image.open(source_path)
        img_final = extract_cloud_hsv(img, level)
        
        imageset_name = f"{character_name}_lv{level}.imageset"
        imageset_path = os.path.join(assets_dir, imageset_name)
        if not os.path.exists(imageset_path):
            os.makedirs(imageset_path)
            
        dest_filename = f"{character_name}_lv{level}.png"
        dest_path = os.path.join(imageset_path, dest_filename)
        img_final.save(dest_path, "PNG")
        
        # Contents.json
        contents = {"images": [{"filename": dest_filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
        print(f"  Saved to {imageset_path}")

    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    if not os.path.exists(assets_dir):
        print("Error: Assets directory not found.")
    else:
        for level, filename in source_files.items():
            process_file(level, filename)
