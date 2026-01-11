
from PIL import Image
import os

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
image_path = os.path.join(assets_dir, "stone_golem_lv1.imageset", "stone_golem_lv1.png")

if os.path.exists(image_path):
    img = Image.open(image_path)
    img = img.convert("RGBA")
    width, height = img.size
    
    print(f"Image Size: {width}x{height}")
    
    # Sample pixels from top corners and top middle
    points = [
        (0, 0), (width-1, 0),       # Top corners
        (0, 10), (width-1, 10),     # Slightly down
        (width//2, 0),              # Top middle
    ]
    
    print("Pixel samples (RGBA):")
    for x, y in points:
        pixel = img.getpixel((x, y))
        print(f"Pos ({x}, {y}): {pixel}")
else:
    print("Image not found")
