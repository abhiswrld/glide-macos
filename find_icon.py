import sys, os, glob
from PIL import Image

def find():
    files = glob.glob("/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/.user_uploaded/*.png")
    for f in sorted(files, key=os.path.getmtime, reverse=True)[:5]:
        img = Image.open(f).convert("RGB")
        w, h = img.size
        # Check center pixel
        r,g,b = img.getpixel((w//2, h//2))
        print(f"File {os.path.basename(f)} size {w}x{h}, center pixel: {r},{g},{b}")
        if g > 150 and g > r*1.2 and g > b*1.2:
            print("  -> Found the green battery!")
            
            # Crop it
            pixels = img.load()
            min_x, min_y = w, h
            max_x, max_y = 0, 0
            
            for y in range(h):
                for x in range(w):
                    pr, pg, pb = pixels[x, y]
                    if pg > 100 and pg > pr*1.2 and pg > pb*1.2:
                        if x < min_x: min_x = x
                        if x > max_x: max_x = x
                        if y < min_y: min_y = y
                        if y > max_y: max_y = y
                        
            if min_x <= max_x and min_y <= max_y:
                print("  -> Bounding box:", min_x, min_y, max_x, max_y)
                cropped = img.crop((min_x, min_y, max_x, max_y))
                new_img = Image.new("RGB", (1024, 1024), "white")
                max_size = 900
                ratio = min(max_size / cropped.width, max_size / cropped.height)
                new_size = (int(cropped.width * ratio), int(cropped.height * ratio))
                resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
                paste_pos = ((1024 - new_size[0]) // 2, (1024 - new_size[1]) // 2)
                new_img.paste(resized, paste_pos)
                new_img.save("app_icon_fixed_final.png")
                print("  -> Saved app_icon_fixed_final.png")
                return

find()
