import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

states_str = """
    @State private var draggingLimit: Double?
    @State private var selectedTab: GlideTab = .battery
    @State private var draggingSailingLimit: Double?
    @State private var draggingHeatThreshold: Double?
    
    @State private var isProcessingDischarge: Bool = false
    @State private var isProcessingLimit: Bool = false
"""

content = content.replace("    @State private var draggingLimit: Double?\n    @State private var selectedTab: GlideTab = .battery\n    @State private var draggingSailingLimit: Double?\n    @State private var draggingHeatThreshold: Double?", states_str)

with open(file_path, "w") as f:
    f.write(content)
