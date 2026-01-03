
import os
import json
import shutil
import unicodedata

# Path to Assets.xcassets
assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

def normalize_nfc(text):
    return unicodedata.normalize('NFC', text)

def create_imageset(file_path, file_name):
    # Normalize filename to NFC (Korean standard for most apps)
    name_without_ext = os.path.splitext(file_name)[0]
    nfc_name = normalize_nfc(name_without_ext)
    
    # Create .imageset directory
    imageset_dir = os.path.join(assets_path, f"{nfc_name}.imageset")
    if not os.path.exists(imageset_dir):
        os.makedirs(imageset_dir)
    
    # Move file to .imageset
    dest_path = os.path.join(imageset_dir, file_name)
    shutil.move(file_path, dest_path)
    
    # Create Contents.json
    contents = {
        "images": [
            {
                "filename": file_name,
                "idiom": "universal",
                "scale": "1x" # Assuming 1x for now, or we can use "single-scale" for vectors
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    # For SVGs, it is often better to preserve vector data
    if file_name.lower().endswith('.svg'):
        contents["properties"] = {
            "preserves-vector-representation": True
        }

    with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        
    print(f"Processed: {file_name} -> {nfc_name}.imageset")

def main():
    if not os.path.exists(assets_path):
        print(f"Error: Path not found: {assets_path}")
        return

    files = os.listdir(assets_path)
    count = 0
    
    for file in files:
        if file.startswith("OfficeLogo_") and (file.endswith(".svg") or file.endswith(".png") or file.endswith(".jpg")):
            file_path = os.path.join(assets_path, file)
            # Only process if it's a file, not a directory
            if os.path.isfile(file_path):
                create_imageset(file_path, file)
                count += 1
                
    print(f"Migration completed. Processed {count} files.")

if __name__ == "__main__":
    main()
