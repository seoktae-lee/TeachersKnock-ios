
import os
from PIL import Image

# Configuration
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"
levels = range(1, 7)

def remove_background_floodfill(image_path):
    img = Image.open(image_path)
    img = img.convert("RGBA")
    width, height = img.size
    pixels = img.load() # Access pixel data directly for speed

    # BFS Flood Fill
    # Start from all corners to ensure we catch background even if corners are split
    queue = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
    visited = set(queue)
    
    # Threshold for "Light Gray" background
    # Top corner was ~208, so we set threshold slightly lower to catch it
    THRESHOLD = 200 

    while queue:
        x, y = queue.pop(0)
        
        r, g, b, a = pixels[x, y]
        
        # Check conditions
        is_transparent = (a == 0)
        is_light_bg = (r > THRESHOLD and g > THRESHOLD and b > THRESHOLD)
        
        should_process = is_transparent or is_light_bg

        if should_process:
            # If it's not already transparent, make it transparent
            if not is_transparent:
                pixels[x, y] = (255, 255, 255, 0)
            
            # Add neighbors
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                nx, ny = x + dx, y + dy
                
                if 0 <= nx < width and 0 <= ny < height:
                    if (nx, ny) not in visited:
                        visited.add((nx, ny))
                        queue.append((nx, ny))

    img.save(image_path, "PNG")
    print(f"Processed (Flood Fill): {image_path}")

def process_level(level):
    imageset_name = f"{character_name}_lv{level}.imageset"
    imageset_path = os.path.join(assets_dir, imageset_name)
    png_filename = f"{character_name}_lv{level}.png"
    png_path = os.path.join(imageset_path, png_filename)
    
    if os.path.exists(png_path):
        remove_background_floodfill(png_path)
    else:
        print(f"File not found: {png_path}")

# Execution
for level in levels:
    print(f"Processing Level {level}...")
    process_level(level)
print("Refined background removal complete.")
