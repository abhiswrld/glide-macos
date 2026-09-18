from PIL import Image
import os

img = Image.open("dmg_background_upscayl_5x_upscayl-standard-4x.png")
# Resize to 1200x800 for 2x retina
img = img.resize((1200, 800), Image.LANCZOS)
img.save("dmg_background.png")
