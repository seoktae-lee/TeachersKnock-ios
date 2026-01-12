
import os
from PIL import Image

def diagnose_holes(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # 1. Identify Transparent Pixels
    transparent_map = [[False for _ in range(height)] for _ in range(width)]
    for x in range(width):
        for y in range(height):
            if pixels[x, y][3] == 0:
                transparent_map[x][y] = True
                
    # 2. Flood Fill from Outside (0,0) to find "True Background"
    visited = [[False for _ in range(height)] for _ in range(width)]
    queue = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
    for qx, qy in queue:
        visited[qx][qy] = True
    
    # Simple BFS for background
    bg_directions = [(-1,0), (1,0), (0,-1), (0,1)]
    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in bg_directions:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height:
                if not visited[nx][ny]:
                    # We can walk on Transparent pixels.
                    # We CANNOT walk on Opaque pixels (Walls).
                    if transparent_map[nx][ny]:
                        visited[nx][ny] = True
                        queue.append((nx, ny))
                        
    # 3. Find "Internal Holes"
    # These are Transparent pixels that were NOT visited.
    holes = []
    hole_visited = [[False for _ in range(height)] for _ in range(width)]
    
    for x in range(width):
        for y in range(height):
            if transparent_map[x][y] and not visited[x][y] and not hole_visited[x][y]:
                # Found a hole component
                component = []
                q = [(x, y)]
                hole_visited[x][y] = True
                while q:
                    cx, cy = q.pop(0)
                    component.append((cx, cy))
                    for dx, dy in bg_directions:
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < width and 0 <= ny < height:
                            if transparent_map[nx][ny] and not visited[nx][ny] and not hole_visited[nx][ny]:
                                hole_visited[nx][ny] = True
                                q.append((nx, ny))
                holes.append(component)
                
    print(f"Found {len(holes)} internal holes.")
    
    for i, hole in enumerate(holes):
        # Stats
        xs = [p[0] for p in hole]
        ys = [p[1] for p in hole]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        center_x = (min_x + max_x) // 2
        center_y = (min_y + max_y) // 2
        
        print(f"Hole {i}: Size {len(hole)}, Center ({center_x}, {center_y}), Bounds [{min_x}-{max_x}, {min_y}-{max_y}]")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv4.imageset/unicorn_lv4.png"
    diagnose_holes(target)
