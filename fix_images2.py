import sys
from PIL import Image

def process_app_icon():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/app_icon_v4_1789610588423.jpg"
    img = Image.open(img_path).convert("RGB")
    
    # Crop to non-white
    bbox = Image.eval(img, lambda x: 255 if x < 250 else 0).getbbox()
    if bbox:
        cropped = img.crop(bbox)
        new_img = Image.new("RGB", (1024, 1024), "white")
        max_size = 950
        ratio = min(max_size / cropped.width, max_size / cropped.height)
        new_size = (int(cropped.width * ratio), int(cropped.height * ratio))
        resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        paste_pos = ((1024 - new_size[0]) // 2, (1024 - new_size[1]) // 2)
        new_img.paste(resized, paste_pos)
        new_img.save("app_icon_fixed2.png")
        print("Fixed App Icon saved.")

def process_dmg_bg():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/dmg_background_v2_1789609467210.jpg"
    img = Image.open(img_path).convert("RGB")
    
    bbox = Image.eval(img, lambda x: 255 if x < 250 else 0).getbbox()
    if bbox:
        cropped = img.crop(bbox)
        
        # Make the arrow slightly smaller, say max width 100
        ratio = 100 / cropped.width
        new_size = (100, int(cropped.height * ratio))
        cropped = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        new_img = Image.new("RGB", (600, 400), "white")
        
        # Center the arrow between 150 and 450 -> X=300, and at Y=190
        paste_x = 300 - cropped.width // 2
        paste_y = 190 - cropped.height // 2
        new_img.paste(cropped, (paste_x, paste_y))
        new_img.save("dmg_background.jpg")
        print("Fixed DMG Background saved.")

process_app_icon()
process_dmg_bg()
