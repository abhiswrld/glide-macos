import re

file_path = "/Users/abhinav/Documents/Glide/Packages/GlideCore/Sources/GlideCore/BatteryReader.swift"
with open(file_path, "r") as f:
    content = f.read()

content = content.replace("public struct BatterySnapshot: Codable, Sendable {", "public struct BatterySnapshot: Codable, Sendable, Equatable {")
with open(file_path, "w") as f:
    f.write(content)
