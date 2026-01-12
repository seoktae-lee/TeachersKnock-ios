
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "cloud"

def print_ascii_alpha(level):
    filename = f"{character_name}_lv{level}.png"
    path = os.path.join(assets_dir, f"{character_name}_lv{level}.imageset", filename)
    
    if not os.path.exists(path):
        print(f"Level {level}: File not found")
        return

    try:
        img = Image.open(path)
        img = img.resize((40, 40)) # Downscale for ASCII
        pixels = img.load()
        w, h = img.size
        
        print(f"--- Level {level} Alpha Map ---")
        for y in range(h):
            line = ""
            for x in range(w):
                r, g, b, a = pixels[x, y]
                if a == 0:
                    line += "." # Transparent
                elif a < 255:
                    line += ":" # Semi-transparent
                else:
                    line += "#" # Opaque
            print(line)
            
    except Exception as e:
        print(f"Error: {e}")

for i in range(1, 6):
    print_ascii_alpha(i)
