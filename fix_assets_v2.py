
import os
import json
import shutil
import unicodedata
import sys

# Path to Assets.xcassets
assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

def normalize_nfc(text):
    return unicodedata.normalize('NFC', text)

def create_imageset(file_path, file_name):
    try:
        # Normalize filename to NFC for consistent usage in Xcode
        name_without_ext, ext = os.path.splitext(file_name)
        nfc_name = normalize_nfc(name_without_ext)
        nfc_filename = nfc_name + ext
        
        # Create .imageset directory
        imageset_dir = os.path.join(assets_path, f"{nfc_name}.imageset")
        if not os.path.exists(imageset_dir):
            os.makedirs(imageset_dir)
            print(f"Created directory: {imageset_dir}")
        
        # Destination path (Renaming file to NFC as well)
        dest_path = os.path.join(imageset_dir, nfc_filename)
        
        # Move and rename file
        shutil.move(file_path, dest_path)
        print(f"Moved: {file_name} -> {dest_path}")
        
        # Create Contents.json
        contents = {
            "images": [
                {
                    "filename": nfc_filename,
                    "idiom": "universal",
                    "scale": "1x"
                },
                {
                    "idiom": "universal",
                    "scale": "2x"
                },
                {
                    "idiom": "universal",
                    "scale": "3x"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }
        
        # For SVGs, preserve vector data
        if ext.lower() == '.svg':
            contents["properties"] = {
                "preserves-vector-representation": True
            }
            # For vector data, we usually typically use a single scale, but the above universal 1x is fine too.
            # Let's adjust to 'single-scale' to be more standard for vectors if needed, 
            # but 'universal' 1x works if 'preserves-vector-representation' is on.
            # Let's clean up the images array for SVG to be single item
            contents["images"] = [
                {
                    "filename": nfc_filename,
                    "idiom": "universal"
                }
            ]

        with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
            
    except Exception as e:
        print(f"Error processing {file_name}: {e}")

def main():
    print(f"Checking assets at: {assets_path}")
    if not os.path.exists(assets_path):
        print(f"Error: Path not found: {assets_path}")
        return

    files = os.listdir(assets_path)
    count = 0
    
    for file in files:
        # Check for OfficeLogo prefix and valid extensions
        # We manually normalize to NFD to match macos filesystem if needed, but startswith should handle it?
        # Let's just check lowercase match to be safe
        if "officelogo_" in file.lower() and (file.lower().endswith(".svg") or file.lower().endswith(".png") or file.lower().endswith(".jpg")):
            file_path = os.path.join(assets_path, file)
            # Only process if it's a file, not a directory
            if os.path.isfile(file_path):
                print(f"Found target file: {file}")
                create_imageset(file_path, file)
                count += 1
                
    print(f"Migration completed. Processed {count} files.")

if __name__ == "__main__":
    main()
