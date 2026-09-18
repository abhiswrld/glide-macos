import sys
from PIL import Image

def process_app_icon():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/app_icon_1789608239533.jpg"
    img = Image.open(img_path).convert("RGB")
    
    width, height = img.size
    pixels = img.load()
    
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    
    # Debug image
    debug_img = Image.new("RGB", (width, height), "black")
    debug_pixels = debug_img.load()

    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            # More robust green check: green must be significantly higher than BOTH red and blue.
            # And it must not be too dark (e.g. black).
            if g > 100 and g > r * 1.2 and g > b * 1.2:
                debug_pixels[x, y] = (0, 255, 0)
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    if min_x < max_x and min_y < max_y:
        print("Found bbox:", min_x, min_y, max_x, max_y)
        cropped = img.crop((min_x, min_y, max_x, max_y))
        
        new_img = Image.new("RGB", (1024, 1024), "white")
        max_size = 900
        ratio = min(max_size / cropped.width, max_size / cropped.height)
        new_size = (int(cropped.width * ratio), int(cropped.height * ratio))
        resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        paste_pos = ((1024 - new_size[0]) // 2, (1024 - new_size[1]) // 2)
        new_img.paste(resized, paste_pos)
        new_img.save("app_icon_fixed3.png")
        print("Saved!")
    else:
        print("Could not find green pixels!")

process_app_icon()
