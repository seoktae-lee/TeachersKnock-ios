import os
import shutil

# Base directory for assets
base_dir = "Teacher'sKnock-ios/App/Assets.xcassets"

# Mapping from Korean name to English name
rename_map = {
    "OfficeLogo_서울시교육청.imageset": "OfficeLogo_Seoul.imageset",
    "OfficeLogo_강원도교육청.imageset": "OfficeLogo_Gangwon.imageset",
    "OfficeLogo_충북교육청.imageset": "OfficeLogo_Chungbuk.imageset",
    "OfficeLogo_충남교육청.imageset": "OfficeLogo_Chungnam.imageset",
    "OfficeLogo_전북교육청.imageset": "OfficeLogo_Jeonbuk.imageset",
    "OfficeLogo_전남교육청.imageset": "OfficeLogo_Jeonnam.imageset",
    "OfficeLogo_경북교육청.imageset": "OfficeLogo_Gyeongbuk.imageset",
    "OfficeLogo_경남교육청.imageset": "OfficeLogo_Gyeongnam.imageset",
    "OfficeLogo_제주도교육청.imageset": "OfficeLogo_Jeju.imageset",
    # Add successful ones just in case/checks
    "OfficeLogo_경기도교육청.imageset": "OfficeLogo_Gyeonggi.imageset",
    "OfficeLogo_부산시교육청.imageset": "OfficeLogo_Busan.imageset",
    "OfficeLogo_대구시교육청.imageset": "OfficeLogo_Daegu.imageset",
    "OfficeLogo_인천시교육청.imageset": "OfficeLogo_Incheon.imageset",
    "OfficeLogo_광주시교육청.imageset": "OfficeLogo_Gwangju.imageset",
    "OfficeLogo_대전시교육청.imageset": "OfficeLogo_Daejeon.imageset",
    "OfficeLogo_울산시교육청.imageset": "OfficeLogo_Ulsan.imageset",
    "OfficeLogo_세종시교육청.imageset": "OfficeLogo_Sejong.imageset",
}

# Normalize string (NFD to NFC might be needed if FS behaves weirdly, but usually Python's os.listdir gives what is on disk)
# We will just list the directory and match by 'contains' or similar if exact match fails.

import unicodedata

def normalize(s):
    return unicodedata.normalize('NFD', s)

def run():
    print(f"Scanning {base_dir}...")
    try:
        files = os.listdir(base_dir)
    except FileNotFoundError:
        print(f"Directory not found: {base_dir}")
        return

    for filename in files:
        # Check against map
        # Try exact match first
        target_name = rename_map.get(filename)
        
        # If not exact match, try normalizing both
        if not target_name:
            norm_filename = normalize(filename)
            for k, v in rename_map.items():
                if normalize(k) == norm_filename:
                    target_name = v
                    break
        
        if target_name:
            src = os.path.join(base_dir, filename)
            dst = os.path.join(base_dir, target_name)
            
            if os.path.exists(dst):
                print(f"Skipping {filename} -> {target_name} (Destination exists)")
                continue

            print(f"Renaming: {filename} -> {target_name}")
            try:
                os.rename(src, dst)
                print("Success")
            except Exception as e:
                print(f"Error: {e}")

if __name__ == "__main__":
    run()
