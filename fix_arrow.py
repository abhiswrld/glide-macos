from PIL import Image

# Load original upscaled image
img = Image.open("dmg_background_upscayl_5x_upscayl-standard-4x.png").convert("RGBA")

# Resize to 1200x800 (retina)
img = img.resize((1200, 800), Image.LANCZOS)
pixels = img.load()

# Find bounding box
min_x = 1200
max_x = -1
min_y = 800
max_y = -1

for y in range(800):
    for x in range(1200):
        r, g, b, a = pixels[x, y]
        if r < 240 or g < 240 or b < 240:
            if x < min_x: min_x = x
            if x > max_x: max_x = x
            if y < min_y: min_y = y
            if y > max_y: max_y = y

if min_x <= max_x and min_y <= max_y:
    print(f"Arrow bounding box: ({min_x}, {min_y}) to ({max_x}, {max_y})")
    
    arrow_w = max_x - min_x + 1
    arrow_h = max_y - min_y + 1
    
    # Extract arrow
    arrow_img = img.crop((min_x, min_y, max_x + 1, max_y + 1))
    
    # Make clean white background
    new_img = Image.new("RGBA", (1200, 800), (255, 255, 255, 255))
    
    # Desired center is (600, 380)
    center_x, center_y = 600, 380
    
    start_x = center_x - arrow_w // 2
    start_y = center_y - arrow_h // 2
    
    # Create mask for pasting. Since the original has white background, pasting it will also paste white.
    # We want to paste the whole block since it's anti-aliased to white anyway.
    new_img.paste(arrow_img, (start_x, start_y))
    
    new_img.save("dmg_background.png")
    print("Successfully moved the arrow and saved to dmg_background.png")
else:
    print("Could not find the arrow.")

