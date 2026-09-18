import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Modify featureToggleRow signature
sig_str = """
    private func featureToggleRow(
        icon: String,
        iconColor: Color,
        label: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isProcessing: Bool = false
    ) -> some View {
"""
content = re.sub(r'    private func featureToggleRow\([\s\S]*?\) -> some View \{', sig_str, content)

# Modify toggle inside featureToggleRow to include progress view
toggle_str = """
            if isProcessing {
                ProgressView().controlSize(.small)
            }
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: GlideTheme.signalGreen))
"""
content = content.replace("""            Toggle("", isOn: isOn)\n                .labelsHidden()\n                .toggleStyle(SwitchToggleStyle(tint: GlideTheme.signalGreen))""", toggle_str)

with open(file_path, "w") as f:
    f.write(content)
