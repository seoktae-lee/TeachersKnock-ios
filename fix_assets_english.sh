#!/bin/bash
cd "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Force rename using wildcards for the korean names
# We use wildcard because NFD/NFC makes exact matching hard in scripts
# Note: This list must match the map we expect

# Rename loop
for f in OfficeLogo_*.imageset; do
    [ -e "$f" ] || continue
    
    new_name=""
    case "$f" in
        *"서울"*) new_name="OfficeLogo_seoul.imageset" ;;
        *"경기"*) new_name="OfficeLogo_gyeonggi.imageset" ;;
        *"부산"*) new_name="OfficeLogo_busan.imageset" ;;
        *"대구"*) new_name="OfficeLogo_daegu.imageset" ;;
        *"인천"*) new_name="OfficeLogo_incheon.imageset" ;;
        *"광주"*) new_name="OfficeLogo_gwangju.imageset" ;;
        *"대전"*) new_name="OfficeLogo_daejeon.imageset" ;;
        *"울산"*) new_name="OfficeLogo_ulsan.imageset" ;;
        *"세종"*) new_name="OfficeLogo_sejong.imageset" ;;
        *"강원"*) new_name="OfficeLogo_gangwon.imageset" ;;
        *"충북"*) new_name="OfficeLogo_chungbuk.imageset" ;;
        *"충남"*) new_name="OfficeLogo_chungnam.imageset" ;;
        *"전북"*) new_name="OfficeLogo_jeonbuk.imageset" ;;
        *"전남"*) new_name="OfficeLogo_jeonnam.imageset" ;;
        *"경북"*) new_name="OfficeLogo_gyeongbuk.imageset" ;;
        *"경남"*) new_name="OfficeLogo_gyeongnam.imageset" ;;
        *"제주"*) new_name="OfficeLogo_jeju.imageset" ;;
    esac
    
    if [ -n "$new_name" ] && [ "$f" != "$new_name" ]; then
        mv "$f" "$new_name"
        echo "Renamed $f to $new_name"
        
        # Also rename inner file if exists
        # Find any OfficeLogo_* file inside
        inner_files=$(find "$new_name" -name "OfficeLogo_*" -type f)
        for inner in $inner_files; do
            # get extension
            ext="${inner##*.}"
            # Construct new filename
            # Remove .imageset from dir name to get base name (OfficeLogo_seoul)
            base_name="${new_name%.imageset}"
            new_inner_name="$new_name/$base_name.$ext"
            
            mv "$inner" "$new_inner_name"
            
            # Update Contents.json
            cat > "$new_name/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$base_name.$ext",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
EOF
        done
    fi
done
