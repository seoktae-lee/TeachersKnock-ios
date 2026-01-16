import os
import shutil
import unicodedata

# Mapping of Korean names to English names
mapping = {
    "서울시교육청": "Seoul",
    "서울시교육청": "Seoul",
    "경기도교육청": "Gyeonggi",
    "경기도교육청": "Gyeonggi",
    "부산시교육청": "Busan",
    "부산시교육청": "Busan",
    "대구시교육청": "Daegu",
    "대구시교육청": "Daegu",
    "인천시교육청": "Incheon",
    "인천시교육청": "Incheon",
    "광주시교육청": "Gwangju",
    "광주시교육청": "Gwangju",
    "대전시교육청": "Daejeon",
    "대전시교육청": "Daejeon",
    "울산시교육청": "Ulsan",
    "울산시교육청": "Ulsan",
    "세종시교육청": "Sejong",
    "세종시교육청": "Sejong",
    "강원도교육청": "Gangwon",
    "강원도교육청": "Gangwon",
    "충북교육청": "Chungbuk",
    "충북교육청": "Chungbuk",
    "충남교육청": "Chungnam",
    "충남교육청": "Chungnam",
    "전북교육청": "Jeonbuk",
    "전북교육청": "Jeonbuk",
    "전남교육청": "Jeonnam",
    "전남교육청": "Jeonnam",
    "경북교육청": "Gyeongbuk",
    "경북교육청": "Gyeongbuk",
    "경남교육청": "Gyeongnam",
    "경남교육청": "Gyeongnam",
    "제주도교육청": "Jeju",
    "제주도교육청": "Jeju"
}

assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

def normalize_str(s):
    return unicodedata.normalize('NFC', s)

print("Starting asset renaming...")

for filename in os.listdir(assets_path):
    if not filename.endswith(".imageset"):
        continue
    
    # Check if it's an OfficeLogo folder
    if not filename.startswith("OfficeLogo_"):
        continue
        
    korean_part = filename.replace("OfficeLogo_", "").replace(".imageset", "")
    
    # Try direct match first
    english_name = mapping.get(korean_part)
    
    # If not found, try normalizing
    if not english_name:
        normalized_korean = normalize_str(korean_part)
        english_name = mapping.get(normalized_korean)
        
    if english_name:
        old_path = os.path.join(assets_path, filename)
        new_filename = f"OfficeLogo_{english_name}.imageset"
        new_path = os.path.join(assets_path, new_filename)
        
        print(f"Renaming: {filename} -> {new_filename}")
        os.rename(old_path, new_path)
        
        # Also rename the json contents if necessary, but usually just the folder name matches the asset name in code
        # However, inside the imageset, there might be files.
        # Let's check the contents.json to see if it needs updates? 
        # Actually, in asset catalogs, the folder name IS the asset name used in code. 
        # The filenames inside don't strictly need to match, but good practice.
        # We will leave filenames inside as is for now to minimize risk, just renaming the folder makes it accessible via the new name.
    else:
        print(f"Skipping unknown logo: {filename}")

print("Renaming complete.")
