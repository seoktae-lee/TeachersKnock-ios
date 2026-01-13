from PIL import Image, ImageFilter
import os

def refine_wolf():
    file_path = "/Users/leeseoktae/Documents/Teacher'sKnock-ios/Teacher'sKnock-ios/App/Assets.xcassets/wolf_lv1.imageset/wolf_lv1.png"
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing: {file_path}")
    
    img = Image.open(file_path).convert("RGBA")
    r, g, b, a = img.split()

    # 1. Edge Smoothing Logic
    # Gaussian Blur the alpha channel slightly to soften jagged pixel edges
    # Radius 0.8 is subtle enough to preserve shape but smooth stairs
    smoothed_a = a.filter(ImageFilter.GaussianBlur(radius=0.8))
    
    # 2. Sharpen Alpha with Levels (Thresholding)
    # This tightens the blurred edge back to a crisp (but smooth) line
    # Mapping values: 0-255 -> push darks down, lights up, but keep gradient for AA
    def smooth_threshold(x):
        # Center around 128, shrink range to [100, 155] for semi-smooth transition
        if x < 20: return 0 
        if x > 230: return 255
        
        # Linear interpolation in between for Anti-aliasing
        # 20..230 -> 0..255
        return int((x - 20) * 255 / (210))

    final_a = smoothed_a.point(smooth_threshold)

    # 3. Combine back
    final_img = Image.merge("RGBA", (r, g, b, final_a))
    
    # Save
    final_img.save(file_path, "PNG")
    print("✅ Successfully refined wolf_lv1.png with edge smoothing.")

if __name__ == "__main__":
    refine_wolf()
