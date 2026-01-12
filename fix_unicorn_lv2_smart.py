
import os
from PIL import Image, ImageFilter, ImageOps

def fix_smart_background(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    # Load image
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    
    # 1. Edge Detection to find "Walls"
    # Convert to grayscale
    gray = img.convert("L")
    # visual edges are white on black
    edges = gray.filter(ImageFilter.FIND_EDGES)
    
    # Threshold edges to make a binary wall map
    # Pixels > 30 are walls
    wall_map = edges.point(lambda p: 255 if p > 30 else 0)
    walls = wall_map.load() # 255 = Wall, 0 = Space
    
    # 2. Flood Fill from Outside to find "Reachable Space"
    # We treat Transparent pixels and Non-Wall pixels as traversable.
    # Actually, we rely on the Alpha channel of original image too.
    # If original alpha is 0, it is "Outside" by definition.
    
    orig_pixels = img.load()
    
    visited = [[False for _ in range(height)] for _ in range(width)]
    queue = []
    
    # Initialize queue with all border pixels or definitely transparent pixels
    for x in range(width):
        for y in range(height):
            # If transparent, it is part of Outside
            if orig_pixels[x, y][3] < 20:
                visited[x][y] = True
                queue.append((x, y))
            # Also add image borders just in case
            elif x == 0 or x == width-1 or y == 0 or y == height-1:
                 # If border pixel is NOT a wall, add it
                 if walls[x, y] == 0:
                     visited[x][y] = True
                     queue.append((x, y))

    # BFS to mark all Outside Reachable pixels
    directions = [(-1,0), (1,0), (0,-1), (0,1)]
    
    while queue:
        cx, cy = queue.pop(0)
        
        for dx, dy in directions:
            nx, ny = cx + dx, cy + dy
            
            if 0 <= nx < width and 0 <= ny < height:
                if not visited[nx][ny]:
                    # Check if Wall
                    # If walls[nx, ny] > 0, it is a wall, stop.
                    # Unless it's transparent? No, walls are from visible pixels.
                    
                    if walls[nx, ny] == 0:
                        visited[nx][ny] = True
                        queue.append((nx, ny))
                        
    # 3. Identify Islands (Unvisited pixels)
    # These are pixels that are NOT Walls, but were NOT reached from Outside.
    # Means they are enclosed by Walls.
    
    # We group them into components.
    island_visited = [[False for _ in range(height)] for _ in range(width)]
    islands = []
    
    for x in range(width):
        for y in range(height):
            # If not visited (Inner) AND not a Wall AND not already processed
            if not visited[x][y] and walls[x, y] == 0 and not island_visited[x][y]:
                # Start new island
                component = []
                q = [(x, y)]
                island_visited[x][y] = True
                while q:
                    icx, icy = q.pop(0)
                    component.append((icx, icy))
                    for idx, idy in directions:
                        inx, iny = icx + idx, icy + idy
                        if 0 <= inx < width and 0 <= iny < height:
                            if not visited[inx][iny] and walls[inx, iny] == 0 and not island_visited[inx][iny]:
                                island_visited[inx][iny] = True
                                q.append((inx, iny))
                islands.append(component)
                
    # 4. Filter and Remove Islands
    # We want to remove islands that are likely "Holes".
    # Characteristics: Small size? White color?
    # Note: If the outline fully encloses the unicorn, the Body itself is an Island.
    # The Body island is huge. The Hole island is small.
    
    print(f"Found {len(islands)} isolated islands.")
    
    islands.sort(key=len, reverse=True)
    
    removed_count = 0
    
    for i, island in enumerate(islands):
        # Heuristic:
        # If island is > 5000 pixels, it's probably the body (Safe guard).
        # We only remove small islands.
        if len(island) > 5000:
            print(f"Skipping Island {i} (Size {len(island)}) - Too big (Likely Body)")
            continue
            
        # Optional: Check color.
        # Check center pixel of island? Or average?
        # Let's count "White" pixels in the island.
        white_pixels = 0
        for px, py in island:
            r, g, b, a = orig_pixels[px, py]
            if r > 200 and g > 200 and b > 200:
                white_pixels += 1
        
        white_ratio = white_pixels / len(island)
        print(f"Island {i}: Size {len(island)}, White Ratio {white_ratio:.2f}")
        
        # If it's mostly white and small, remove it.
        if white_ratio > 0.5:
            print(f"  -> Removing Island {i}")
            for px, py in island:
                orig_pixels[px, py] = (0, 0, 0, 0) # Make transparent
                removed_count += 1
        else:
            print(f"  -> Keeping Island {i} (Not white enough)")

    img.save(image_path)
    print(f"Smart fix complete. Removed {removed_count} pixels.")
    print(f"Saved to {image_path}")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    fix_smart_background(target)
