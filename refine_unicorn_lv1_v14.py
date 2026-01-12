
import os
import sys
from PIL import Image, ImageFilter, ImageEnhance

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f38f8551-c251-4a79-9b98-00195a631120"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
filename = "uploaded_image_1768211867295.png" # Premade PNG (Transparent)
folder_prefix = "unicorn"
level = 1

def process_lv1_hq(img):
    img = img.convert("RGBA")
    # Sharpening (Unsharp Mask)
    sharpened = img.filter(ImageFilter.UnsharpMask(radius=2, percent=150, threshold=3))
    # Enhance Contrast
    enhancer = ImageEnhance.Contrast(sharpened)
    enhanced = enhancer.enhance(1.1) 
    return enhanced

def resize_and_canvas(img, target_height=815, canvas_size=(1024, 1024)):
    bbox = img.getbbox()
    if not bbox: return img
    cropped = img.crop(bbox)
    
    # Resize
    aspect_ratio = cropped.width / cropped.height
    new_height = target_height
    new_width = int(new_height * aspect_ratio)
    
    # Lanczos Upscaling
    resized = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Paste
    final_img = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    paste_x = (canvas_size[0] - new_width) // 2
    paste_y = (canvas_size[1] - new_height) // 2
    final_img.paste(resized, (paste_x, paste_y))
    
    return final_img

print("Refining Lv 1 (V14: Max Size 815px)...")
path = os.path.join(artifacts_dir, filename)

if os.path.exists(path):
    img = Image.open(path)
    img = process_lv1_hq(img)
    img = resize_and_canvas(img, target_height=815) # Match Stone Golem
    
    imageset_path = os.path.join(assets_dir, f"{folder_prefix}_lv{level}.imageset")
    if not os.path.exists(imageset_path): os.makedirs(imageset_path)
    dest_filename = f"{folder_prefix}_lv{level}.png"
    save_path = os.path.join(imageset_path, dest_filename)
    
    img.save(save_path, "PNG")
    print(f"Saved to {save_path} (Size: {img.size})")
else:
    print("File not found.")
