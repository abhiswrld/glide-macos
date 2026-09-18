import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Add states
states_str = """
    @State private var isProcessingDischarge: Bool = false
    @State private var isProcessingLimit: Bool = false
"""
content = content.replace("    @State private var selectedTab: GlideTab = .battery", states_str + "\n    @State private var selectedTab: GlideTab = .battery")

# Modify Limit Slider / Toggle
# Wait, Limit is not a toggle, it's a slider.
# Actually, the user said "make the power adapter and limit 80% text bigger"
# For the Limit 80% feature, there is a toggle for Sailing mode maybe? Or limit section.
