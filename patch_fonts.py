import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Replace .caption2 with .system(size: 14) for the specific block
old_block = """            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }"""
new_block = """            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }"""
content = content.replace(old_block, new_block)

with open(file_path, "w") as f:
    f.write(content)
