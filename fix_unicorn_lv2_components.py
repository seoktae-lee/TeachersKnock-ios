
import os
from PIL import Image

def fix_components(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # 1. Identify "Target Pixels" (Pure White)
    # Using same threshold as before: RGB > 240
    
    visited = [[False for _ in range(height)] for _ in range(width)]
    components = []
    
    for x in range(width):
        for y in range(height):
            if not visited[x][y]:
                r, g, b, a = pixels[x, y]
                # Is it a Target Pixel? (White and Opaque)
                if r > 240 and g > 240 and b > 240 and a > 0:
                     # Start Component BFS
                     component = []
                     q = [(x, y)]
                     visited[x][y] = True
                     while q:
                         cx, cy = q.pop(0)
                         component.append((cx, cy))
                         
                         for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                             nx, ny = cx + dx, cy + dy
                             if 0 <= nx < width and 0 <= ny < height:
                                 if not visited[nx][ny]:
                                     nr, ng, nb, na = pixels[nx, ny]
                                     if nr > 240 and ng > 240 and nb > 240 and na > 0:
                                         visited[nx][ny] = True
                                         q.append((nx, ny))
                     
                     if component:
                         components.append(component)

    print(f"Found {len(components)} white components.")
    
    # 2. Analyze Components
    # We want to find the "Hole Between Legs".
    # Features:
    # - Located in Lower Half? (y > height/2)
    # - Centered horizontally? (x around width/2)
    # - Size?
    
    removed_count = 0
    img_center_x = width // 2
    img_center_y = height // 2
    
    for i, comp in enumerate(components):
        # Calculate bounding box and center of component
        xs = [p[0] for p in comp]
        ys = [p[1] for p in comp]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        
        center_x = (min_x + max_x) // 2
        center_y = (min_y + max_y) // 2
        
        size = len(comp)
        
        print(f"Component {i}: Size {size}, Center ({center_x}, {center_y}), Bounds [{min_x}-{max_x}, {min_y}-{max_y}]")
        
        # Heuristic for "Background between legs"
        # It should be somewhat low (y > img_center_y * 0.8?)
        # It should be significant size > 50? (Total removed before was 928)
        
        # If it's very small (<10), ignore (highlights/noise).
        if size < 10:
            print(f"  -> Keep (Small)")
            continue
            
        # Check location
        # Legs are usually below the center.
        if center_y < img_center_y:
            print(f"  -> Keep (Too high - likely eyes/highlights)")
            continue
            
        # If it passes checks, remove it.
        print(f"  -> REMOVING (Suspected Hole)")
        for px, py in comp:
            pixels[px, py] = (0, 0, 0, 0)
        removed_count += size

    img.save(image_path)
    print(f"Component fix complete. Removed {removed_count} pixels.")
    print(f"Saved to {image_path}")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    fix_components(target)
