
import os
from PIL import Image

def fix_eyes(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # We found Hole 2 at Center (614, 227) is the likely eye.
    # We will run a flood fill from this point to fill the transparent hole with White.
    
    seed_point = (614, 227)
    
    # Check if seed is transparent
    if pixels[seed_point][3] != 0:
        print("Seed point is NOT transparent! Aborting to avoid damage.")
        return
        
    # Perform Fill
    visited = set()
    queue = [seed_point]
    
    filled_count = 0
    
    while queue:
        cx, cy = queue.pop(0)
        
        if (cx, cy) in visited:
            continue
        visited.add((cx, cy))
        
        # Fill with White
        pixels[cx, cy] = (255, 255, 255, 255)
        filled_count += 1
        
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                # If neighbor is transparent, continue filling
                if pixels[nx, ny][3] == 0:
                     queue.append((nx, ny))
                    
    img.save(image_path)
    print(f"Filled eye at {seed_point} with white. Modified {filled_count} pixels.")
    print(f"Saved to {image_path}")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv4.imageset/unicorn_lv4.png"
    fix_eyes(target)
