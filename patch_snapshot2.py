import re

file_path = "/Users/abhinav/Documents/Glide/Packages/GlideCore/Sources/GlideCore/BatteryReader.swift"
with open(file_path, "r") as f:
    content = f.read()

eq_func = """
    public static func == (lhs: BatterySnapshot, rhs: BatterySnapshot) -> Bool {
        return lhs.percent == rhs.percent &&
               lhs.isCharging == rhs.isCharging &&
               lhs.isPluggedIn == rhs.isPluggedIn &&
               lhs.isFull == rhs.isFull &&
               lhs.cycleCount == rhs.cycleCount &&
               lhs.healthPercent == rhs.healthPercent &&
               lhs.temperatureC == rhs.temperatureC &&
               lhs.watts == rhs.watts &&
               lhs.timeRemainingMinutes == rhs.timeRemainingMinutes
    }
"""

content = content.replace("    public let raw: [String: Int]\n}", f"    public let raw: [String: Int]\n{eq_func}\n}}")
with open(file_path, "w") as f:
    f.write(content)
