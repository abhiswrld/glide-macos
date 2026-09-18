from PIL import Image

img = Image.open("dmg_background_upscayl_5x_upscayl-standard-4x.png").convert("RGBA")

# 1x image
img1x = img.resize((600, 400), Image.LANCZOS)
img1x.save("bg_1x.png")

# 2x image
img2x = img.resize((1200, 800), Image.LANCZOS)
img2x.save("bg_2x.png")
