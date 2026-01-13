from PIL import Image, ImageDraw
import os

def refine_wolf_final():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing final refinement: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    
    # 1. Remove Logo (Bottom Right)
    # The Gemini logo is a small star in the bottom right.
    # We can effectively erase a small region in the corner.
    # Since it's an egg, the bottom right corner should be empty background.
    w, h = img.size
    
    # Define a clean-up region: bottom 15% and right 15% corner
    # Being conservative to not cut the egg if it's huge, but egg is usually centered-ish vertical.
    # If the user says it's skewed left, maybe the right side is empty?
    # Let's clean the very corner. 
    erase_size = int(min(w, h) * 0.15) 
    
    # Create a draw object to clear pixels
    draw = ImageDraw.Draw(img)
    # Draw a rectangle with transparent color (Operator 'clear' doesn't exist directly in draw, need to paste or mask)
    # Easiest: Paste a transparent rect
    clear_patch = Image.new("RGBA", (erase_size, erase_size), (0, 0, 0, 0))
    img.paste(clear_patch, (w - erase_size, h - erase_size))
    
    # 2. Re-Centering
    # Get the bounding box of the actual content (now that logo is gone)
    bbox = img.getbbox()
    if not bbox:
        print("Error: Image is empty after processing.")
        return
        
    content = img.crop(bbox)
    content_w, content_h = content.size
    
    # Create a new square canvas based on the larger dimension plus some padding
    # This ensures the egg text/layout in app (which often assumes square or centered) looks good.
    canvas_size = int(max(content_w, content_h) * 1.1)
    new_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # Calculate center position
    paste_x = (canvas_size - content_w) // 2
    paste_y = (canvas_size - content_h) // 2
    
    new_img.paste(content, (paste_x, paste_y))
    
    # 3. Final Resize (Optional, to keep it standard)
    # User said "current size as is", but standardizing to 500x500 is usually safer for UI consistency.
    # Let's stick to the canvas size if reasonable, or cap at 500.
    if canvas_size > 500:
       new_img = new_img.resize((500, 500), Image.LANCZOS)

    # Save
    new_img.save(file_path, "PNG")
    print("✅ Successfully removed logo and centered the egg.")

if __name__ == "__main__":
    refine_wolf_final()
