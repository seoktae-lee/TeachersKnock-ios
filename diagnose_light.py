
import os
from PIL import Image
from collections import Counter

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"
targets = [2, 3, 4, 6]

print("--- Analyzing Light Pixels (RGB > 180) ---")

for level in targets:
    imageset_name = f"{character_name}_lv{level}.imageset"
    filename = f"{character_name}_lv{level}.png"
    filepath = os.path.join(assets_dir, imageset_name, filename)
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        continue
        
    img = Image.open(filepath).convert("RGBA")
    pixels = img.getdata()
    
    light_pixels = []
    
    for r, g, b, a in pixels:
        if a > 0: # Visible
            # Average brightness
            brightness = (r + g + b) // 3
            if brightness > 180:
                light_pixels.append(brightness)
    
    if light_pixels:
        count = len(light_pixels)
        avg = sum(light_pixels) // count
        print(f"\n[Level {level}]")
        print(f"Total Visible Light Pixels (>180): {count}")
        print(f"Average Brightness of Light Pixels: {avg}")
        
        # Show some distribution
        hist = Counter(light_pixels)
        print("Distribution (Brightness : Count):")
        for b in sorted(hist.keys(), reverse=True)[:10]: # Top 10 brightest values
             print(f"  {b}: {hist[b]}")
    else:
        print(f"\n[Level {level}] No light pixels found > 180")
