
import os
import shutil
import json

# Configuration
artifacts_dir = "/Users/leeseoktae/.gemini/antigravity/brain/f2111beb-d3bc-4713-a6c5-2db524bbecd7"
assets_dir = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
character_name = "stone_golem"

# Map level to source file
source_files = {
    1: "uploaded_image_0_1768122609164.jpg",
    2: "uploaded_image_1_1768122609164.jpg",
    3: "uploaded_image_2_1768122609164.jpg",
    4: "uploaded_image_3_1768122609164.jpg",
    5: "uploaded_image_4_1768122609164.jpg",
    6: "uploaded_image_1768123158801.jpg"
}

def create_imageset(level, source_filename):
    imageset_name = f"{character_name}_lv{level}.imageset"
    imageset_path = os.path.join(assets_dir, imageset_name)
    
    # Creates directory
    if not os.path.exists(imageset_path):
        os.makedirs(imageset_path)
        print(f"Created directory: {imageset_path}")
    
    # Destination filename
    dest_filename = f"{character_name}_lv{level}.jpg"
    dest_path = os.path.join(imageset_path, dest_filename)
    
    # Copy file
    source_path = os.path.join(artifacts_dir, source_filename)
    if os.path.exists(source_path):
        shutil.copy2(source_path, dest_path)
        print(f"Copied {source_filename} to {dest_filename}")
    else:
        print(f"Error: Source file not found: {source_path}")
        return

    # Create Contents.json
    contents = {
        "images": [
            {
                "filename": dest_filename,
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    with open(os.path.join(imageset_path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Created Contents.json for Level {level}")

# Execution
if not os.path.exists(assets_dir):
    print(f"Error: Assets directory not found: {assets_dir}")
else:
    for level, filename in source_files.items():
        create_imageset(level, filename)
    print("All assets processed.")
