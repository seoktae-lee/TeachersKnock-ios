
import os
import shutil

assets_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"
print(f"Scanning {assets_path}")

try:
    files = os.listdir(assets_path)
    print(f"Found {len(files)} files")
except Exception as e:
    print(f"Error listing dir: {e}")
    exit(1)

for f in files:
    # Check if this is an OfficeLogo svg
    if "OfficeLogo_" in f and f.endswith(".svg"):
        print(f"Processing: {f}")
        
        # Determine name for directory (strip extension)
        # We don't change normalization here to avoid mismatch, just use what we have in the filesystem
        name = os.path.splitext(f)[0]
        
        # Create directory
        dir_name = os.path.join(assets_path, name + ".imageset")
        if not os.path.exists(dir_name):
            try:
                os.makedirs(dir_name)
                print(f"Created dir: {dir_name}")
            except Exception as e:
                print(f"Failed to create dir: {e}")
                continue
        
        # Move file
        src = os.path.join(assets_path, f)
        dst = os.path.join(dir_name, f)
        try:
            shutil.move(src, dst)
            print(f"Moved {src} -> {dst}")
        except Exception as e:
            print(f"Failed to move: {e}")
            continue
            
        # Create Contents.json
        # IMPORTANT: Xcode expects standard normalization. If we keep NFD here, it might still fail if Xcode is strict.
        # But for now, let's just make sure it's valid JSON referring to the file.
        json_path = os.path.join(dir_name, "Contents.json")
        try:
            with open(json_path, "w") as jf:
                jf.write(f'''{{
  "images" : [
    {{
      "filename" : "{f}",
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
            print(f"Created Contents.json for {name}")
        except Exception as e:
            print(f"Failed to write json: {e}")

print("Done")
