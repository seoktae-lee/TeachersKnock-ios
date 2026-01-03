
import os
import shutil
import unicodedata

assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Mapping: Korean fragment -> English suffix
mapping = {
    "서울": "seoul",
    "경기": "gyeonggi",
    "부산": "busan",
    "대구": "daegu",
    "인천": "incheon",
    "광주": "gwangju",
    "대전": "daejeon",
    "울산": "ulsan",
    "세종": "sejong",
    "강원": "gangwon",
    "충북": "chungbuk",
    "충남": "chungnam",
    "전북": "jeonbuk",
    "전남": "jeonnam",
    "경북": "gyeongbuk",
    "경남": "gyeongnam",
    "제주": "jeju"
}

def normalize(text):
    return unicodedata.normalize('NFC', text)

print(f"Scanning {assets_path}")
files = os.listdir(assets_path)

for f in files:
    # We only care about directories starting with OfficeLogo
    if not f.startswith("OfficeLogo"):
        continue
        
    nfc_name = normalize(f)
    print(f"Checking: {nfc_name}")
    
    found_key = None
    for k, v in mapping.items():
        if k in nfc_name:
            found_key = v
            break
            
    if found_key:
        new_dir_name = f"OfficeLogo_{found_key}.imageset"
        old_path = os.path.join(assets_path, f)
        new_path = os.path.join(assets_path, new_dir_name)
        
        if old_path != new_path:
            try:
                shutil.move(old_path, new_path)
                print(f"RENAMED: {f} -> {new_dir_name}")
                
                # Update inner file and contents.json
                # Find the inner file
                if os.path.exists(new_path):
                    inner_files = os.listdir(new_path)
                    for inner in inner_files:
                        if inner.startswith("OfficeLogo") and inner.endswith(".svg"):
                            # Rename inner file to match outer dir for consistency (though not strictly required)
                            new_inner_name = f"OfficeLogo_{found_key}.svg"
                            old_inner_path = os.path.join(new_path, inner)
                            new_inner_path = os.path.join(new_path, new_inner_name)
                            shutil.move(old_inner_path, new_inner_path)
                            
                            # Rewrite contents.json
                            json_path = os.path.join(new_path, "Contents.json")
                            with open(json_path, "w") as jf:
                                jf.write(f'''{{
  "images" : [
    {{
      "filename" : "{new_inner_name}",
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
                            print(f"  Fixed inner file and JSON")
                            
            except Exception as e:
                print(f"Error renaming {f}: {e}")
    else:
        print(f"No mapping found for {nfc_name}")
