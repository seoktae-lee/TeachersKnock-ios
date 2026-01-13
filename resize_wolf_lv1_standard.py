from PIL import Image
import os

def resize_wolf_lv1_standard():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing resize (Enlarging to 72% Height) for: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    
    # 1. Trim to content
    bbox = img.getbbox()
    if bbox:
        content = img.crop(bbox)
    else:
        content = img
        
    # 2. Target Dimensions
    # Canvas: 1024x1024
    canvas_size = 1024
    
    # OLD: 65% -> ~665px
    # NEW: 72% -> ~737px (Closer to Unicorn's 750px)
    target_height = int(canvas_size * 0.72)
    
    # Calculate width preserving aspect ratio
    aspect_ratio = content.width / content.height
    target_width = int(target_height * aspect_ratio)
    
    # Resize Content
    resized_content = content.resize((target_width, target_height), Image.LANCZOS)
    
    # 3. Paste into center of Canvas
    new_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    paste_x = (canvas_size - target_width) // 2
    paste_y = (canvas_size - target_height) // 2
    
    new_img.paste(resized_content, (paste_x, paste_y))
    
    # Save
    new_img.save(file_path, "PNG")
    
    print(f"✅ Successfully resized wolf_lv1.png to 1024x1024 (Content Height: {target_height}px, 72%).")

if __name__ == "__main__":
    resize_wolf_lv1_standard()
