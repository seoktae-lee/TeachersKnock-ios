
import os
from PIL import Image, ImageDraw

def remove_islands(image_path, output_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()

    # Create a mask for "background-like" pixels (near white or transparent)
    # We will treat "white" pixels as potential background to be removed if they are isolated
    # But wait, the unicorn itself is white.
    # Strategy: Find "holes" in the alpha channel that are actually white opaque pixels?
    # No, the user says "background exists". This usually means the background removal tool missed spots enclosed by the character.
    # These spots are likely pure white (if original bg was white) or whatever the bg color was.
    # Assuming the current image has transparent background *outside*, but opaque "background color" *inside* holes.
    
    # Let's detect pixels that are very light (near white) AND opaque.
    # Then find connected components of these pixels.
    # If a component touches the edge of the image, it's the main background (already removed hopefully).
    # If it's isolated inside the character, it's likely a hole we want to verify.
    # BUT, the Unicorn is white! This is dangerous.
    
    # Alternative Strategy:
    # The "background" between legs might be distinct if it's not perfectly white, or if we rely on the user's description.
    # Let's look for "contained" transparent areas? No, they are opaque currently.
    
    # Updated Strategy:
    # 1. Identify all transparent pixels (Alpha < 10).
    # 2. Flood fill from (0,0) to identify the "Outside" world.
    # 3. Any non-transparent pixel that is NOT reachable from the outside is "Inside" the character.
    # 4. Within the "Inside" area, we look for pixels that look like background.
    # Since I don't know the exact background color, I'll assume it's white/light gray (common for stock images).
    # However, the unicorn is also white.
    
    # Better approach for "between front legs":
    # Usually these are specific coordinates.
    # Since I can't interactively see, I will try to detect "islands of transparency" if they were partially removed? 
    # Or more likely, they are just solid white blocks.
    
    # Let's try to detect areas that are White (R>240, G>240, B>240) but are surrounded by non-white pixels?
    # This is risky.
    
    # Let's try to make everything that is "White" AND "Surrounded by outline" transparent?
    # No, the body is white.
    
    # Let's use a "Magic Wand" approach.
    # I'll create a debug image first highlighting "White" areas that are NOT the main body?
    # Hard to distinguish.
    
    # Wait, the user said "background exists".
    # Often, automatic tools fail to remove background in "holes" (a topological hole).
    # If I flood fill the transparent area from the outside, I get the "Outer Background".
    # Any other transparent area is an "Inner Hole" (already done).
    # Any OPAQUE area is the character.
    # The problem is that the "Inner Hole" allows the background to persist as OPAQUE pixels.
    # So we have OPAQUE pixels that SHOULD be transparent.
    
    # Since the Unicorn is white, distinguishing "Body White" from "Background White" is hard without edge detection.
    # However, background usually has a uniform color.
    # Let's try to detect if there's a specific "Background Color" that matches the corner pixels of the ORIGINAL image?
    # But the current image has transparent corners.
    
    # Let's look at the `unicorn_lv2.png` alpha channel.
    # If I can't distinguish, I might need to ask the user, or...
    # I'll try to refine the "Edges".
    # Maybe the "background" is slightly off-white?
    
    # Let's gamble on a "Flood Fill" from a specific point? 
    # I can't know the point.
    
    # Let's try the "Island" approach with a twist:
    # Iterate all transparent pixels.
    # If a transparent pixel is adjacent to a WHITE pixel, that white pixel might be edge or body.
    
    # Let's try a very aggressive "remove white near edges" approach? No.
    
    # BACKUP PLAN:
    # Just apply the `rembg` library if installed? No, I don't have it.
    
    # Let's look at the alpha channel...
    # Actually, a common artifact is that the background is #FFFFFF and the body is #FDFDFD or similar.
    # Or, the background is perfectly flat color.
    
    # I will simply try to make "Near White" (250+) pixels transparent, BUT only if they are disconnected from the main body center?
    # No, the body center is white.
    
    # Let's blindly try to remove "holes" using a coordinate heuristic?
    # "Between front legs" suggests the lower center-left area.
    
    # Let's try to run a "Smart Erase" at specific coordinates?
    # I'll search for white pixels in the bottom-middle area that are surrounded by outlines.
    
    # Actually, let's create a visual map of white pixels first to see if the "hole" stands out.
    pass

# I'll actually write a script that converts White to Red temporarily for the user to debug?
# Or better, I will apply a "fuzzy erase" on white colors, but I suspect it will eat the body.
# 
# Let's search for the "hole".
# A hole in the legs usually implies a closed loop of outline.
# If I can detect the outline (dark pixels), I can find regions of white inside it.
# 
# Algorithm:
# 1. Binarize image: Dark pixels (Outline) vs Light pixels (Body + Background).
# 2. Find Connected Components of "Light pixels".
# 3. The biggest component is the Body+Outside (if outline is not closed) OR just Body (if outline separates body from bg).
#    Wait, "Outside" is transparent.
#    So, "Light pixels" includes Transparent (Previous Background) and White (Body + Remaining Background).
#    Actually, Transparent pixels are effectively "Outside".
#    So we simulate "Flood Fill" from (0,0) on the "Light + Transparent" map.
#    If the legs form a closed loop, the "Background between legs" will NOT be reached by the flood fill if we treat "Outline" as walls.
#    Wait, if the background between legs is OPAQUE white, and the outline surrounds it...
#    Then a flood fill starting from (0,0) (Transparent) will NOT reach the internal white pixels IF the outline is continuous/closed.
#    AND IF the internal pixels are not transparent yet.
#    
#    So:
#    1. Treat "Dark-ish" pixels as impassable walls.
#    2. Flood fill from (0,0) using "Transparent" capability.
#    3. Any "White" pixel that is NOT reached is "Inside a looped wall".
#    4. These are candidates for "Background in Hole".
#    5. We set them to Transparent.
    
    backup_path = image_path.replace(".png", "_backup_lv2.png")
    img.save(backup_path)
    print(f"Backed up to {backup_path}")

    # Wall definition: Dark pixels.
    # The unicorn outline is likely not pure black, but "darker" than white.
    # Let's say Luminance < 200 is a wall?
    # Unicorn body is very light.
    
    width, height = img.size
    pixels = img.load()
    
    # Create a map of visited pixels
    visited = [[False for _ in range(height)] for _ in range(width)]
    
    # Queue for BFS
    queue = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
    for x, y in queue:
        visited[x][y] = True

    # Wall threshold
    WALL_LUM_THRESHOLD = 180 
    
    while queue:
        x, y = queue.pop(0)
        
        # Check neighbors
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x + dx, y + dy
            
            if 0 <= nx < width and 0 <= ny < height and not visited[nx][ny]:
                r, g, b, a = pixels[nx, ny]
                
                # Verify if it is a wall
                # Calculate Luminance
                lum = 0.299*r + 0.587*g + 0.114*b
                
                # If transparent, it's walkable (obviously, it's outside)
                # If it's lighter than wall threshold, it's walkable (it's empty space or body connected to outside)
                # If it's darker, it's a wall.
                
                is_wall = (a > 50) and (lum < WALL_LUM_THRESHOLD)
                
                if not is_wall:
                    visited[nx][ny] = True
                    queue.append((nx, ny))
    
    # Now, any pixel that is NOT visited but is WHITE (high luminance) is a candidate for "Trapped Background"
    # Why? Because it's surrounded by walls (dark outlines) but we couldn't reach it from outside.
    # Note: This assumes the unicorn body itself is REACHABLE from outside (i.e. outline is not fully closed around the body).
    # Usually outlines don't close the *entire* body off from the edge of the image, 
    # BUT for a "Unicorn", the outline might fully enclose the white interior!
    # If the outline fully encloses the unicorn, then the ENTIRE body will be unvisited.
    # In that case, we delete the WHOLE UNICORN! That's bad.
    
    # Refinement:
    # "Holes" between legs are usually much smaller than the body.
    # So, we identify "Unvisited White Components".
    # Calculate their area.
    # The largest unvisited component is the Body.
    # Smaller unvisited components are "Holes".
    
    # Step 2: Find Connected Components of "Unvisited" pixels.
    # We treat all "Unvisited" pixels as "Foreground".
    # We segment them.
    
    unvisited_map = [[not visited[x][y] for y in range(height)] for x in range(width)]
    
    components = []
    w_visited = [[False for _ in range(height)] for _ in range(width)]
    
    for x in range(width):
        for y in range(height):
            if unvisited_map[x][y] and not w_visited[x][y]:
                # Start a new component
                component = []
                q = [(x, y)]
                w_visited[x][y] = True
                while q:
                    cx, cy = q.pop(0)
                    component.append((cx, cy))
                    for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < width and 0 <= ny < height:
                            if unvisited_map[nx][ny] and not w_visited[nx][ny]:
                                w_visited[nx][ny] = True
                                q.append((nx, ny))
                components.append(component)
    
    print(f"Found {len(components)} enclosed components.")
    
    # Sort by size (descending)
    components.sort(key=len, reverse=True)
    
    if not components:
        print("No enclosed components found. Outline might be open?")
        return
        
    # The largest one is the Body.
    # All others are holes to be deleted.
    body_component = components[0]
    holes = components[1:]
    
    print(f"Body size: {len(body_component)} pixels")
    print(f"Holes to remove: {len(holes)}")
    for i, hole in enumerate(holes):
        print(f"  Hole {i+1}: {len(hole)} pixels")
        for hx, hy in hole:
            pixels[hx, hy] = (0, 0, 0, 0) # Make transparent

    img.save(image_path)
    print(f"Saved fixed image to {image_path}")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    remove_islands(target, target)
