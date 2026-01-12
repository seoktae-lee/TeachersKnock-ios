
import os
from PIL import Image

def analyze_legs(image_path):
    if not os.path.exists(image_path):
        print("File not found.")
        return

    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # Define a window in the bottom center where "between legs" might be.
    # Assuming 1024x1024 image.
    # Legs usually around y=700-900?
    # Center x=512.
    
    print(f"Image size: {width}x{height}")
    
    # Grid sample
    print("Sampling bottom-center region (x: 300-500, y: 300-600, step: 20):")
    # Reduced range safely
    start_y = height // 2
    end_y = height - 20
    start_x = width // 3
    end_x = width * 2 // 3
    
    for y in range(start_y, end_y, 40):
        row = []
        for x in range(start_x, end_x, 40):
            if x < width and y < height:
                p = pixels[x, y]
                # Format: (R,G,B,A)
                row.append(f"({x},{y}):{p}")
        if row:
            print(" | ".join(row))

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    analyze_legs(target)
