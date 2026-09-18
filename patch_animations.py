import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Remove pulse: true from all statePill calls
content = content.replace(', pulse: true', '')

with open(file_path, "w") as f:
    f.write(content)

file_path = "/Users/abhinav/Documents/Glide/Packages/GlideCore/Sources/GlideCore/BatteryReader.swift"
with open(file_path, "r") as f:
    content = f.read()

# Remove watts and timeRemainingMinutes from BatterySnapshot ==
old_eq = """    public static func == (lhs: BatterySnapshot, rhs: BatterySnapshot) -> Bool {
        return lhs.percent == rhs.percent &&
               lhs.isCharging == rhs.isCharging &&
               lhs.isPluggedIn == rhs.isPluggedIn &&
               lhs.isFull == rhs.isFull &&
               lhs.cycleCount == rhs.cycleCount &&
               lhs.healthPercent == rhs.healthPercent &&
               lhs.temperatureC == rhs.temperatureC &&
               lhs.watts == rhs.watts &&
               lhs.timeRemainingMinutes == rhs.timeRemainingMinutes
    }"""
new_eq = """    public static func == (lhs: BatterySnapshot, rhs: BatterySnapshot) -> Bool {
        return lhs.percent == rhs.percent &&
               lhs.isCharging == rhs.isCharging &&
               lhs.isPluggedIn == rhs.isPluggedIn &&
               lhs.isFull == rhs.isFull &&
               lhs.cycleCount == rhs.cycleCount &&
               lhs.healthPercent == rhs.healthPercent
    }"""
content = content.replace(old_eq, new_eq)

with open(file_path, "w") as f:
    f.write(content)
