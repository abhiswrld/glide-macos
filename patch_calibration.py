import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

cal_old = """                                if on {
                                    calibrationPhase = 1
                                } else {"""
cal_new = """                                if on {
                                    calibrationPhase = 1
                                    if forceDischargeEnabled {
                                        forceDischargeEnabled = false
                                        isForceDischarging = false
                                        daemon.setForceDischarge(false)
                                    }
                                } else {"""
content = content.replace(cal_old, cal_new)

with open(file_path, "w") as f:
    f.write(content)
