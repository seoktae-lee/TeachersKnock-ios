
import os
from PIL import Image, ImageDraw

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
unicorn_path = os.path.join(assets_dir, "unicorn_lv1.imageset/unicorn_lv1.png")

output_path = "/Users/leeseoktae/.gemini/antigravity/brain/e4cccea5-2d22-4a9d-9aa6-49a97ca1dbd5/unicorn_debug.png"

if os.path.exists(unicorn_path):
    img = Image.open(unicorn_path)
    # Create a white background
    bg = Image.new("RGB", img.size, (0, 0, 0))
    # Paste the alpha channel as grayscale
    alpha = img.split()[-1]
    bg.paste(alpha, (0, 0))
    
    # Draw bbox
    bbox = img.getbbox()
    draw = ImageDraw.Draw(bg)
    if bbox:
        draw.rectangle(bbox, outline="red", width=5)
    
    bg.save(output_path)
    print(f"Saved debug image to {output_path}")
    print(f"BBox: {bbox}")
else:
    print("Unicorn image not found")
