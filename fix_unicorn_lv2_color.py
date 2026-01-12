
import os
from PIL import Image

def fix_color_background(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    removed_count = 0
    
    # Threshold for "White" background
    # Unicorn is Golden (Low Blue). Background is White (High Blue).
    # We will remove pixels that are very light and have high blue content.
    
    THRESHOLD = 240
    
    for item in data:
        r, g, b, a = item
        # Check if it is near white
        if r > THRESHOLD and g > THRESHOLD and b > THRESHOLD and a > 0:
            new_data.append((0, 0, 0, 0)) # Make transparent
            removed_count += 1
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(image_path)
    print(f"Index clean up complete. Removed {removed_count} pixels.")
    print(f"Saved to {image_path}")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    fix_color_background(target)
