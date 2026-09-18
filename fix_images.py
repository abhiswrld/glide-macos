import sys
from PIL import Image

def process_app_icon():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/app_icon_flat_1789608472702.jpg"
    img = Image.open(img_path).convert("RGB")
    
    # Find bounding box of non-white pixels
    bbox = Image.eval(img, lambda x: 255 - x).getbbox()
    if bbox:
        # Crop to bbox
        cropped = img.crop(bbox)
        # Create a new 1024x1024 white image
        new_img = Image.new("RGB", (1024, 1024), "white")
        # Resize cropped image to fit within 950x950 to leave slight padding
        max_size = 950
        ratio = min(max_size / cropped.width, max_size / cropped.height)
        new_size = (int(cropped.width * ratio), int(cropped.height * ratio))
        resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        # Paste into center
        paste_pos = ((1024 - new_size[0]) // 2, (1024 - new_size[1]) // 2)
        new_img.paste(resized, paste_pos)
        new_img.save("app_icon_fixed.png")
        print("Fixed App Icon saved.")

def process_dmg_bg():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/dmg_background_v2_1789609467210.jpg"
    img = Image.open(img_path).convert("RGB")
    
    # Find bounding box of non-white pixels
    bbox = Image.eval(img, lambda x: 255 if x < 250 else 0).getbbox()
    if bbox:
        # Crop arrow
        cropped = img.crop(bbox)
        
        # We might want to resize the arrow if it's too big.
        # Let's say max width 150px
        if cropped.width > 150:
            ratio = 150 / cropped.width
            new_size = (150, int(cropped.height * ratio))
            cropped = cropped.resize(new_size, Image.Resampling.LANCZOS)
        
        # Create 600x400 white background
        new_img = Image.new("RGB", (600, 400), "white")
        
        # Icons are at Y=190. Center of arrow should be at (300, 190)
        paste_x = 300 - cropped.width // 2
        paste_y = 190 - cropped.height // 2
        new_img.paste(cropped, (paste_x, paste_y))
        new_img.save("dmg_background.jpg")
        print("Fixed DMG Background saved.")

process_app_icon()
process_dmg_bg()
