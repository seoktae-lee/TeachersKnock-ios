
from PIL import Image, ImageDraw, ImageFont

# Dimensions for iPhone 6.7" Display (e.g. 1290 x 2796)
width = 1290
height = 2796
color = (240, 240, 240) # Light gray
text_color = (100, 100, 100)

img = Image.new('RGB', (width, height), color)
draw = ImageDraw.Draw(img)

# Draw some text
try:
    # Try to load a system font
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 80)
except:
    font = ImageFont.load_default()

text = "In-App Purchase\nReview Screenshot"
# Simple centering logic
bbox = draw.textbbox((0, 0), text, font=font)
text_w = bbox[2] - bbox[0]
text_h = bbox[3] - bbox[1]

x = (width - text_w) / 2
y = (height - text_h) / 2

draw.text((x, y), text, font=font, fill=text_color, align="center")

# Save
output_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/review_screenshot.png"
img.save(output_path)
print(f"Created screenshot at: {output_path}")
