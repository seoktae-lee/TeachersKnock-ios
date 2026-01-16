import os
import shutil

# Base path for assets
base_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Mapping of Korean part to English suffix
# Format: Korean Name -> English Suffix
# Note: The Korean names are copy-pasted from the directory listing to ensure encoding matches
mapping = {
    "OfficeLogo_강원도교육청.imageset": "OfficeLogo_Gangwon.imageset",
    "OfficeLogo_경남교육청.imageset": "OfficeLogo_Gyeongnam.imageset",
    "OfficeLogo_경북교육청.imageset": "OfficeLogo_Gyeongbuk.imageset",
    "OfficeLogo_광주시교육청.imageset": "OfficeLogo_Gwangju.imageset",
    "OfficeLogo_대구시교육청.imageset": "OfficeLogo_Daegu.imageset",
    "OfficeLogo_대전시교육청.imageset": "OfficeLogo_Daejeon.imageset",
    "OfficeLogo_서울시교육청.imageset": "OfficeLogo_Seoul.imageset",
    "OfficeLogo_세종시교육청.imageset": "OfficeLogo_Sejong.imageset",
    "OfficeLogo_울산시교육청.imageset": "OfficeLogo_Ulsan.imageset",
    "OfficeLogo_인천시교육청.imageset": "OfficeLogo_Incheon.imageset",
    "OfficeLogo_전남교육청.imageset": "OfficeLogo_Jeonnam.imageset",
    "OfficeLogo_전북교육청.imageset": "OfficeLogo_Jeonbuk.imageset",
    "OfficeLogo_제주도교육청.imageset": "OfficeLogo_Jeju.imageset",
    "OfficeLogo_충남교육청.imageset": "OfficeLogo_Chungnam.imageset",
    "OfficeLogo_충북교육청.imageset": "OfficeLogo_Chungbuk.imageset"
}

def rename_assets():
    if not os.path.exists(base_path):
        print(f"Error: Base path {base_path} does not exist.")
        return

    print(f"Scanning {base_path}...")
    
    # Get list of all files in directory
    files = os.listdir(base_path)
    
    # Normalize unicode names just in case, but we will rely on partial matching if exact fail
    # Actually, let's try to match by decoding/encoding tricks or just iterating
    
    for filename in files:
        if filename in mapping:
            old_path = os.path.join(base_path, filename)
            new_path = os.path.join(base_path, mapping[filename])
            
            if os.path.exists(new_path):
                print(f"Skipping {filename} -> {mapping[filename]}: Target already exists")
                continue
                
            print(f"Renaming {filename} -> {mapping[filename]}")
            try:
                os.rename(old_path, new_path)
            except Exception as e:
                print(f"Failed to rename {filename}: {e}")
        else:
            # Fallback for normalization differences (NFD vs NFC)
            # Try to match independently of normalization
            import unicodedata
            normalized_filename = unicodedata.normalize('NFC', filename)
            for k, v in mapping.items():
                if unicodedata.normalize('NFC', k) == normalized_filename:
                    old_path = os.path.join(base_path, filename)
                    new_path = os.path.join(base_path, v)
                    
                    if os.path.exists(new_path):
                        print(f"Skipping {filename} (norm match) -> {v}: Target already exists")
                        continue
                        
                    print(f"Renaming {filename} (norm match) -> {v}")
                    try:
                        os.rename(old_path, new_path)
                    except Exception as e:
                        print(f"Failed to rename {filename}: {e}")
                    break

if __name__ == "__main__":
    rename_assets()
