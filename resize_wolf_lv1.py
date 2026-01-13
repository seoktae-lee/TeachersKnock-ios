from PIL import Image
import os

def resize_wolf_lv1_padding():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing resize (padding) for: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    
    # 1. Trim to content first to get actual size
    bbox = img.getbbox()
    if bbox:
        content = img.crop(bbox)
    else:
        content = img
        
    content_w, content_h = content.size
    
    # 2. Add Padding to make the visual size smaller
    # Previous logic was canvas = content * 1.1 (Very tight fit -> looks big)
    # Let's try canvas = content * 1.5 (More padding -> looks smaller in fixed frame)
    # Adjust this factor to tune size. 1.4 ~ 1.5 is usually good for "Shop Item" look.
    padding_factor = 1.45 
    
    new_canvas_size = int(max(content_w, content_h) * padding_factor)
    
    new_img = Image.new("RGBA", (new_canvas_size, new_canvas_size), (0, 0, 0, 0))
    
    # Center paste
    paste_x = (new_canvas_size - content_w) // 2
    paste_y = (new_canvas_size - content_h) // 2
    
    new_img.paste(content, (paste_x, paste_y))
    
    # 3. Resize back to standard resolution (e.g. 500x500) for clean asset
    # This ensures the pixel density is fine but the "content" is smaller relative to the file boundaries.
    final_size = 500
    new_img = new_img.resize((final_size, final_size), Image.LANCZOS)
    
    # Save
    new_img.save(file_path, "PNG")
    print("✅ Successfully resized wolf_lv1.png (Added padding to reduce visual scale).")

if __name__ == "__main__":
    resize_wolf_lv1_padding()
