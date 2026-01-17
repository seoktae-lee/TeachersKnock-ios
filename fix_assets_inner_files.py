import os
import shutil
import json

# Path to Assets.xcassets
assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Mapping from English Key (Capitalized) to expected filename
keys = [
    "Seoul", "Gyeonggi", "Busan", "Daegu", "Incheon",
    "Gwangju", "Daejeon", "Ulsan", "Sejong", "Gangwon",
    "Chungbuk", "Chungnam", "Jeonbuk", "Jeonnam",
    "Gyeongbuk", "Gyeongnam", "Jeju"
]

def main():
    if not os.path.exists(assets_path):
        print(f"Error: Path not found: {assets_path}")
        return

    print(f"Scanning {assets_path} for inner file fixes...")

    for key in keys:
        dirname = f"OfficeLogo_{key}.imageset"
        dirpath = os.path.join(assets_path, dirname)
        
        if not os.path.exists(dirpath):
            print(f"Warning: Directory not found: {dirname}")
            continue
            
        # List files in directory
        files = os.listdir(dirpath)
        
        # Find the image file (svg, png)
        image_file = None
        for f in files:
            if f == "Contents.json":
                continue
            if f.lower().endswith(('.svg', '.png', '.jpg', '.jpeg', '.pdf')):
                image_file = f
                break
        
        if not image_file:
            print(f"Warning: No image file found in {dirname}")
            continue
            
        # Target filename
        _, ext = os.path.splitext(image_file)
        target_filename = f"OfficeLogo_{key}{ext}"
        
        target_path = os.path.join(dirpath, target_filename)
        current_path = os.path.join(dirpath, image_file)
        
        # Rename if different
        if image_file != target_filename:
            print(f"Renaming {image_file} -> {target_filename} in {dirname}")
            shutil.move(current_path, target_path)
        else:
            print(f"File name already correct in {dirname}: {image_file}")

        # Always update Contents.json to be safe and consistent
        print(f"Updating Contents.json for {dirname}")
        json_path = os.path.join(dirpath, "Contents.json")
        
        # Helper to determine if we need preserve-vector
        properties_block = ""
        if ext.lower() == ".svg" or ext.lower() == ".pdf":
             properties_block = ''',
  "properties" : {
    "preserves-vector-representation" : true
  }'''
        
        # Create sanitized JSON content
        # We use Universal 1x. For vector, usually Scale is ignored or treated as point size.
        # But to be safe for vector, we can omit scale or set to "1x".
        # Let's clean it up to standard format.
        
        content = f'''{{
  "images" : [
    {{
      "filename" : "{target_filename}",
      "idiom" : "universal"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }}{properties_block}
}}'''
        
        with open(json_path, "w") as f:
            f.write(content)
            
    print("Fix complete.")

if __name__ == "__main__":
    main()
