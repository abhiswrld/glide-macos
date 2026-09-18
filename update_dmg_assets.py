import os

file_path = "/Users/abhinav/Documents/Glide/build_dmg.sh"
with open(file_path, "r") as f:
    content = f.read()

content = content.replace("dmg_background.jpg", "dmg_background.png")

with open(file_path, "w") as f:
    f.write(content)
