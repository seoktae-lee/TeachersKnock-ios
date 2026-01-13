from PIL import Image, ImageFilter
import os

def refine_wolf_lv5():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv5.imageset/wolf_lv5.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing wolf_lv5 refinement: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    datas = img.getdata()
    
    new_data = []
    
    # 1. Despill Logic (Remove Green Tint)
    for item in datas:
        r, g, b, a = item
        
        # Target subtle green halos (Face, Legs)
        # If Green is slightly dominant over Red AND Blue
        if g > r and g > b:
            new_g = max(r, b)
            new_data.append((r, new_g, b, a))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    # 2. Alpha Erosion (Trim Edge)
    r, g, b, a = img.split()
    
    # MinFilter(3) erodes 1px
    a = a.filter(ImageFilter.MinFilter(3))
    
    # Soften
    a = a.filter(ImageFilter.GaussianBlur(0.5))
    
    # Re-apply alpha
    img = Image.merge("RGBA", (r, g, b, a))
    
    # Save
    img.save(file_path, "PNG")
    print("✅ Successfully refined wolf_lv5.png (Despill + Erosion).")

if __name__ == "__main__":
    refine_wolf_lv5()
