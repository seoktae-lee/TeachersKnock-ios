
import os
from PIL import Image

def remove_green_and_resize(image_path):
    if not os.path.exists(image_path):
        print(f"File not found: {image_path}")
        return

    img = Image.open(image_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    
    # Chroma Key parameters
    # Target Green is usually very bright green.
    # Simple heuristic: G should be significantly larger than R and B.
    
    for item in data:
        r, g, b, a = item
        
        # Check for Green Screen Green
        # Heuristic: Green is dominant.
        # Adjustable validation: G > 100, G > R + 20, G > B + 20
        # The uploaded image looks like specialized green screen, so it might be pure green.
        
        is_green = (g > 100) and (g > r + 30) and (g > b + 30)
        
        if is_green:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    # 2. Crop
    bbox = img.getbbox()
    if bbox:
        cropped_img = img.crop(bbox)
        print(f"Cropped Size: {cropped_img.size}")
        
        # 3. Resize
        target_height = 750
        ratio = target_height / float(cropped_img.size[1])
        new_width = int(float(cropped_img.size[0]) * ratio)
        resized_img = cropped_img.resize((new_width, target_height), Image.Resampling.LANCZOS)
        print(f"Resized Size: {resized_img.size}")
        
        # 4. Center on 1024x1024
        final_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        x_offset = (1024 - new_width) // 2
        y_offset = (1024 - target_height) // 2
        final_img.paste(resized_img, (x_offset, y_offset))
        
        final_img.save(image_path)
        print(f"Processed and saved to {image_path}")
    else:
        print("Error: Image is empty after background removal")

if __name__ == "__main__":
    target = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/unicorn_lv2.imageset/unicorn_lv2.png"
    remove_green_and_resize(target)
