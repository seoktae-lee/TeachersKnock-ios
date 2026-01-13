from PIL import Image, ImageChops, ImageFilter
import os
import math

def distance(c1, c2):
    (r1, g1, b1) = c1[:3]
    (r2, g2, b2) = c2[:3]
    return math.sqrt((r1 - r2)**2 + (g1 - g2)**2 + (b1 - b2)**2)

def process_wolf_replacement_robust():
    # Paths
    source_path = "/Users/leeseoktae/.gemini/antigravity/brain/eda5e6b3-4b47-4d6a-89c9-2cbc524fdd16/uploaded_image_1768292470271.jpg"
    target_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(source_path):
        print(f"Error: Source file not found at {source_path}")
        return

    print(f"Processing improved replacement from: {source_path}")
    
    # 1. Load Image
    img = Image.open(source_path).convert("RGBA")
    datas = img.getdata()
    
    # 2. Sample Background Color (Top-Left)
    bg_color = datas[0] # (R, G, B, A)
    print(f"Sampled Background Color: {bg_color}")
    
    # 3. Apply Background Removal with Tolerance
    # Tolerance of 80 is usually good for JPEG artifacts on solid backgrounds
    TOLERANCE = 80 
    
    new_data = []
    
    for item in datas:
        # Calculate distance to background color
        if distance(item, bg_color) < TOLERANCE:
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    # 4. Crop
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    # 5. Resize if needed (Constraint to 500px width)
    if img.width > 500:
        ratio = 500 / img.width
        new_height = int(img.height * ratio)
        img = img.resize((500, new_height), Image.LANCZOS)
    
    # 6. Smooth Edges (Erosion + Blur)
    # Extract Alpha
    r, g, b, a = img.split()
    
    # Erode alpha slightly to remove "green halo" pixels at the fringe
    # 1 pixel erosion often helps
    # Simple manual erosion: min filter
    a = a.filter(ImageFilter.MinFilter(3)) # 3x3 kernel -> erodes ~1px
    
    # Blur alpha for softness
    a = a.filter(ImageFilter.GaussianBlur(1.0))
    
    # Push levels to sharpen the blur (Smooth Thresholding)
    def smooth_threshold(x):
        if x < 10: return 0
        if x > 200: return 255
        return int((x - 10) / 190 * 255)
        
    a = a.point(smooth_threshold)
    
    img = Image.merge("RGBA", (r, g, b, a))

    # Save
    img.save(target_path, "PNG")
    print("✅ Successfully replaced wolf_lv1.png with robust background removal.")

if __name__ == "__main__":
    process_wolf_replacement_robust()
