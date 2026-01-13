from PIL import Image, ImageFilter
import os

def refine_wolf_lv2():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv2.imageset/wolf_lv2.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing wolf_lv2 refinement: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    datas = img.getdata()
    
    new_data = []
    
    # 1. Despill Logic (Remove Green Tint)
    # Turn green pixels into neutral colors
    for item in datas:
        r, g, b, a = item
        
        # If Green is the dominant channel (Green Halo)
        if g > r and g > b:
            # Simple Despill: Clamp Green to the max of Red and Blue
            # This turns pure green into dark gray/black, and light green into white/gray
            new_g = max(r, b)
            
            # If it was VERY green, it might be background that wasn't removed.
            # If alpha is low, it's likely an edge.
            
            new_data.append((r, new_g, b, a))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    # 2. Alpha Erosion (Trim Edge)
    # The halo is usually on the very edge. Removing 1px often fixes it.
    r, g, b, a = img.split()
    
    # MinFilter(3) is a 3x3 kernel, effectively eroding 1px from all sides
    a = a.filter(ImageFilter.MinFilter(3))
    
    # Soften the new edge
    a = a.filter(ImageFilter.GaussianBlur(0.5))
    
    # Re-apply alpha
    img = Image.merge("RGBA", (r, g, b, a))
    
    # Save
    img.save(file_path, "PNG")
    print("✅ Successfully refined wolf_lv2.png (Despill + Erosion).")

if __name__ == "__main__":
    refine_wolf_lv2()
