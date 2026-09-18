from PIL import Image

# Load original upscaled image
img = Image.open("dmg_background_upscayl_5x_upscayl-standard-4x.png").convert("RGBA")

# Resize to 600x400 (standard 1x resolution)
img = img.resize((600, 400), Image.LANCZOS)
img.save("dmg_background.png")
print("Saved 600x400 background!")
