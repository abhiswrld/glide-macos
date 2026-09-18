import sys
from PIL import Image

def process_app_icon():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/app_icon_1789608239533.jpg"
    img = Image.open(img_path).convert("RGB")
    
    # Let's find the bbox by looking only at pixels that are definitively green (g > 150, r < 100, b < 100)
    width, height = img.size
    pixels = img.load()
    
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if g > 150 and r < 120 and b < 120:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    if min_x <= max_x and min_y <= max_y:
        print("Found green bbox:", min_x, min_y, max_x, max_y)
        cropped = img.crop((min_x, min_y, max_x, max_y))
        
        new_img = Image.new("RGB", (1024, 1024), "white")
        max_size = 900
        ratio = min(max_size / cropped.width, max_size / cropped.height)
        new_size = (int(cropped.width * ratio), int(cropped.height * ratio))
        resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        paste_pos = ((1024 - new_size[0]) // 2, (1024 - new_size[1]) // 2)
        new_img.paste(resized, paste_pos)
        new_img.save("app_icon_fixed5.png")
        print("Saved app_icon_fixed5.png")
    else:
        print("Could not find green pixels!")

process_app_icon()
