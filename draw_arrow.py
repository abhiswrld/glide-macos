from PIL import Image, ImageDraw

bg = Image.open("dmg_background.png").convert("RGBA")

# Center coordinate for arrow in 1200x800 image
cx = 600
cy = 380

# Size of the arrow
aw = 160
ah = 100

ax = cx - aw // 2
ay = cy - ah // 2

draw = ImageDraw.Draw(bg)

# Stem
stem_h = 40
stem_w = 80
draw.rectangle(
    [ax, cy - stem_h//2, ax + stem_w, cy + stem_h//2],
    fill=(40, 200, 80, 255)
)

# Triangle head
head_points = [
    (ax + stem_w, cy - ah//2),
    (ax + aw, cy),
    (ax + stem_w, cy + ah//2)
]
draw.polygon(head_points, fill=(40, 200, 80, 255))

bg.save("dmg_background.png")
