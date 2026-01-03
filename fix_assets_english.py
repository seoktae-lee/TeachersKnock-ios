
import os
import shutil
import unicodedata

# Path to Assets.xcassets
assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Mapping from Korean Name (as typically normalized) to English Key
# Note: keys are based on the enum cases in NoticeData.swift
mapping = {
    "서울시교육청": "seoul",
    "경기도교육청": "gyeonggi",
    "부산시교육청": "busan",
    "대구시교육청": "daegu",
    "인천시교육청": "incheon",
    "광주시교육청": "gwangju",
    "대전시교육청": "daejeon",
    "울산시교육청": "ulsan",
    "세종시교육청": "sejong",
    "강원도교육청": "gangwon",
    "충북교육청": "chungbuk",
    "충남교육청": "chungnam",
    "전북교육청": "jeonbuk",
    "전남교육청": "jeonnam",
    "경북교육청": "gyeongbuk",
    "경남교육청": "gyeongnam",
    "제주도교육청": "jeju"
}

def normalize(text):
    # Normalize to NFC for comparison
    return unicodedata.normalize('NFC', text)

def main():
    if not os.path.exists(assets_path):
        print(f"Error: Path not found: {assets_path}")
        return

    print(f"Scanning {assets_path}...")
    
    files = os.listdir(assets_path)
    
    for file in files:
        # We are looking for "OfficeLogo_KOREANNAME.svg" or existing directories
        if not file.startswith("OfficeLogo_"):
            continue
            
        # Deconstruct filename
        # file might be "OfficeLogo_서울시교육청.svg" or "OfficeLogo_서울시교육청.imageset"
        # We need the "서울시교육청" part.
        
        name_part = file.replace("OfficeLogo_", "")
        # Remove extensions to get the raw name
        if name_part.endswith(".imageset"):
            raw_name = name_part.replace(".imageset", "")
            ext = ""
            is_dir = True
        else:
            root, ext = os.path.splitext(name_part)
            raw_name = root
            is_dir = False
            
        # Normalize raw_name to match our mapping keys
        nfc_name = normalize(raw_name)
        
        if nfc_name in mapping:
            english_key = mapping[nfc_name]
            new_name = f"OfficeLogo_{english_key}"
            
            old_path = os.path.join(assets_path, file)
            
            # If it's already an imageset directory
            if is_dir:
                new_path = os.path.join(assets_path, f"{new_name}.imageset")
                if old_path != new_path:
                    shutil.move(old_path, new_path)
                    print(f"Renamed Dir: {file} -> {new_name}.imageset")
                    
                    # Also need to update contents.json inside if it refers to the old filename?
                    # Generally Contents.json refers to the filename inside.
                    # If we renamed the directory, the file inside might still be korean. 
                    # Let's rename the file inside too for cleanliness.
                    inner_files = os.listdir(new_path)
                    for inner in inner_files:
                        if inner.startswith("OfficeLogo_") and inner != "Contents.json":
                            # Rename inner file
                            _, inner_ext = os.path.splitext(inner)
                            new_inner = f"{new_name}{inner_ext}"
                            shutil.move(os.path.join(new_path, inner), os.path.join(new_path, new_inner))
                            
                            # Rewrite Contents.json
                            json_path = os.path.join(new_path, "Contents.json")
                            with open(json_path, "w") as f:
                                f.write(f'''{{
  "images" : [
    {{
      "filename" : "{new_inner}",
      "idiom" : "universal"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }},
  "properties" : {{
    "preserves-vector-representation" : true
  }}
}}''')
                            print(f"  Updated inner file to {new_inner}")

            # If it's a loose file (which seems to be the current state causing issues)
            else:
                 # Create new imageset dir
                new_dir = os.path.join(assets_path, f"{new_name}.imageset")
                if not os.path.exists(new_dir):
                    os.makedirs(new_dir)
                
                # Move file into it and rename
                new_filename = f"{new_name}{ext}"
                shutil.move(old_path, os.path.join(new_dir, new_filename))
                
                # Create Contents.json
                json_path = os.path.join(new_dir, "Contents.json")
                with open(json_path, "w") as f:
                    f.write(f'''{{
  "images" : [
    {{
      "filename" : "{new_filename}",
      "idiom" : "universal"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }},
  "properties" : {{
    "preserves-vector-representation" : true
  }}
}}''')
                print(f"Migrated File: {file} -> {new_name}.imageset/{new_filename}")
        else:
            print(f"Skipping unknown file: {file} (parsed as {nfc_name})")

if __name__ == "__main__":
    main()
