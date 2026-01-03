#!/bin/bash
cd "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Using exact strings copied from list_dir output (NFD)
mv "OfficeLogo_강원도교육청.imageset" "OfficeLogo_gangwon.imageset"
mv "OfficeLogo_경기도교육청.imageset" "OfficeLogo_gyeonggi.imageset"
mv "OfficeLogo_경남교육청.imageset" "OfficeLogo_gyeongnam.imageset"
mv "OfficeLogo_경북교육청.imageset" "OfficeLogo_gyeongbuk.imageset"
mv "OfficeLogo_광주시교육청.imageset" "OfficeLogo_gwangju.imageset"
mv "OfficeLogo_대구시교육청.imageset" "OfficeLogo_daegu.imageset"
mv "OfficeLogo_대전시교육청.imageset" "OfficeLogo_daejeon.imageset"
mv "OfficeLogo_부산시교육청.imageset" "OfficeLogo_busan.imageset"
mv "OfficeLogo_서울시교육청.imageset" "OfficeLogo_seoul.imageset"
mv "OfficeLogo_세종시교육청.imageset" "OfficeLogo_sejong.imageset"
mv "OfficeLogo_울산시교육청.imageset" "OfficeLogo_ulsan.imageset"
mv "OfficeLogo_인천시교육청.imageset" "OfficeLogo_incheon.imageset"
mv "OfficeLogo_전남교육청.imageset" "OfficeLogo_jeonnam.imageset"
mv "OfficeLogo_전북교육청.imageset" "OfficeLogo_jeonbuk.imageset"
mv "OfficeLogo_제주도교육청.imageset" "OfficeLogo_jeju.imageset"
mv "OfficeLogo_충남교육청.imageset" "OfficeLogo_chungnam.imageset"
mv "OfficeLogo_충북교육청.imageset" "OfficeLogo_chungbuk.imageset"

# Now rename the inner files too!
# Loop through the renamed directories
for dir in OfficeLogo_*.imageset; do
    [ -d "$dir" ] || continue
    # Base name without OfficeLogo_ and .imageset
    english_name=${dir#OfficeLogo_}
    english_name=${english_name%.imageset}
    
    # Check inner content
    # Inner file might still be Korean
    inner_files=$(find "$dir" -type f -name "OfficeLogo_*.svg")
    for inner in $inner_files; do
        mv "$inner" "$dir/OfficeLogo_$english_name.svg"
        
        # Rewrite Contents.json
        cat > "$dir/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "OfficeLogo_$english_name.svg",
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
done
