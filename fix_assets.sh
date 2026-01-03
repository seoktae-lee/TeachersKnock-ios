#!/bin/bash
cd "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets"

# Loop through all OfficeLogo svgs
for f in OfficeLogo_*.svg; do
    # Check if file exists to avoid error if glob fails
    [ -e "$f" ] || continue
    
    # Get filename without extension
    filename=$(basename "$f")
    name="${filename%.*}"
    
    # Create imageset directory
    mkdir -p "$name.imageset"
    
    # Move file into imageset
    mv "$f" "$name.imageset/"
    
    # Create Contents.json
    cat > "$name.imageset/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$filename",
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
    echo "Processed $filename"
done
