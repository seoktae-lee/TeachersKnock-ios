
import os
from PIL import Image

assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
unicorn_path = os.path.join(assets_dir, "unicorn_lv1.imageset/unicorn_lv1.png")
backup_path = os.path.join(os.path.dirname(unicorn_path), "unicorn_lv1_backup.png")

if os.path.exists(unicorn_path):
    img = Image.open(unicorn_path).convert("RGBA")
    
    # 1. Backup original
    if not os.path.exists(backup_path):
        img.save(backup_path)
        print(f"Backed up to {backup_path}")

    # 2. Clean noise (Threshold alpha)
    datas = img.getdata()
    new_data = []
    for item in datas:
        # If alpha is less than threshold, make it fully transparent
        if item[3] < 20:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    
    # 3. Crop to content
    bbox = img.getbbox()
    if bbox:
        cropped_img = img.crop(bbox)
        print(f"Cropped Size: {cropped_img.size}")
        
        # 4. Resize (Target height ~750px)
        target_height = 750
        ratio = target_height / float(cropped_img.size[1])
        new_width = int(float(cropped_img.size[0]) * ratio)
        resized_img = cropped_img.resize((new_width, target_height), Image.Resampling.LANCZOS)
        print(f"Resized Size: {resized_img.size}")
        
        # 5. Paste into center of 1024x1024
        final_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        x_offset = (1024 - new_width) // 2
        y_offset = (1024 - target_height) // 2
        final_img.paste(resized_img, (x_offset, y_offset))
        
        final_img.save(unicorn_path, "PNG")
        print(f"Saved processed image to {unicorn_path}")
    else:
        print("Error: Empty image after cleaning")

else:
    print("Unicorn image not found")
