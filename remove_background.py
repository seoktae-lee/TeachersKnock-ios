
import os
import json
from PIL import Image

# Configuration
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"
levels = range(1, 7) # 1 to 6

def convert_to_transparent(image_path, output_path):
    img = Image.open(image_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    new_data = []
    for item in datas:
        # Change all white (also shades of whites) to transparent
        # Threshold: > 240 for R, G, B
        if item[0] > 240 and item[1] > 240 and item[2] > 240:
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Converted {image_path} -> {output_path}")

def update_contents_json(json_path, new_filename):
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    # Update filename in images list
    for image in data['images']:
        image['filename'] = new_filename
        
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated {json_path}")

def process_level(level):
    imageset_name = f"{character_name}_lv{level}.imageset"
    imageset_path = os.path.join(assets_dir, imageset_name)
    
    if not os.path.exists(imageset_path):
        print(f"Directory not found: {imageset_path}")
        return

    # Find existing jpg
    jpg_filename = f"{character_name}_lv{level}.jpg"
    jpg_path = os.path.join(imageset_path, jpg_filename)
    
    if os.path.exists(jpg_path):
        # Define new png path
        png_filename = f"{character_name}_lv{level}.png"
        png_path = os.path.join(imageset_path, png_filename)
        
        # Convert
        convert_to_transparent(jpg_path, png_path)
        
        # Update JSON
        json_path = os.path.join(imageset_path, "Contents.json")
        update_contents_json(json_path, png_filename)
        
        # Remove old jpg
        os.remove(jpg_path)
        print(f"Removed old file: {jpg_path}")
    else:
        print(f"JPG file not found for level {level}")

# Execution
for level in levels:
    process_level(level)
print("Background removal complete.")
