import sys
from PIL import Image

def check_center():
    img_path = "/Users/abhinav/.gemini/antigravity-ide/brain/eb3d465e-87ea-4165-97d3-50c79f58fdc0/app_icon_1789608239533.jpg"
    img = Image.open(img_path).convert("RGB")
    width, height = img.size
    
    print("Center pixel:", img.getpixel((width//2, height//2)))
    print("Center-50 pixel:", img.getpixel((width//2 - 50, height//2)))
    
check_center()
