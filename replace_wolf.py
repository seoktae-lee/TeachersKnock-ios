from PIL import Image, ImageChops
import os

def process_wolf_replacement():
    # Paths
    source_path = "/Users/leeseoktae/.gemini/antigravity/brain/eda5e6b3-4b47-4d6a-89c9-2cbc524fdd16/uploaded_image_1768292470271.jpg"
    target_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(source_path):
        print(f"Error: Source file not found at {source_path}")
        return

    print(f"Processing replacement from: {source_path}")
    
    # 1. Load Image
    img = Image.open(source_path).convert("RGBA")
    
    # 2. Chroma Key (Green Screen Removal)
    # Target Green: (0, 255, 0) approx.
    # We'll use a threshold logic.
    datas = img.getdata()
    new_data = []
    
    for item in datas:
        # Green is dominant: G > R+10 and G > B+10 and G > 100
        # Adjust thresholds for the specific shade of green in the user's image
        # Based on visual inspect, it's a fairly pure green.
        if item[1] > 150 and item[0] < 100 and item[2] < 100:
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    # 3. Crop to content (Trim transparent borders)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    # 4. Resize to match existing asset size context (optional but good for consistency)
    # Let's check original size first if needed, but standard 300-400px is usually good.
    # For now, we'll keep the cropped size high quality, assuming the app scales it (scaledToFit).
    # But to be safe, let's constrain max width to 500px to avoid huge assets.
    if img.width > 500:
        ratio = 500 / img.width
        new_height = int(img.height * ratio)
        img = img.resize((500, new_height), Image.LANCZOS)
        
    # 5. Save
    img.save(target_path, "PNG")
    print("✅ Successfully replaced wolf_lv1.png with background removed.")

if __name__ == "__main__":
    process_wolf_replacement()
