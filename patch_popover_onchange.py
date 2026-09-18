import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Modify the call to featureToggleRow for forceDischargeEnabled
old_toggle = """                featureToggleRow(
                    icon: "minus.circle",
                    iconColor: GlideTheme.signalRed,
                    label: "Force Discharge",
                    subtitle: "Run entirely on battery",
                    isOn: $forceDischargeEnabled
                )"""
new_toggle = """                featureToggleRow(
                    icon: "minus.circle",
                    iconColor: GlideTheme.signalRed,
                    label: "Force Discharge",
                    subtitle: "Run entirely on battery",
                    isOn: $forceDischargeEnabled,
                    isProcessing: isProcessingDischarge
                )
                .onChange(of: forceDischargeEnabled) { _ in
                    isProcessingDischarge = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                        isProcessingDischarge = false
                    }
                }"""
content = content.replace(old_toggle, new_toggle)

with open(file_path, "w") as f:
    f.write(content)
