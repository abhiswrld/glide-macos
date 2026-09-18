import re

file_path = "/Users/abhinav/Documents/Glide/Glide/PopoverView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Fix Check for Updates in aboutSection
about_old = """                HStack {
                    Spacer()
                    Button("Check for Updates") {
                        SparkleManager.shared.checkForUpdates()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlideTheme.signalBlue)
                    .buttonStyle(.plain)
                    Spacer()
                }"""
about_new = """                HStack {
                    Spacer()
                    Button("Check for Updates") {
                        SparkleManager.shared.checkForUpdates()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlideTheme.signalBlue)
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 4)"""
content = content.replace(about_old, about_new)

# Fix Bottom Bar
bottom_bar_old = """    private var bottomBar: some View {
        HStack {
            Text("Glide 2.0")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(DaemonModel.shared == nil ? GlideTheme.signalRed : GlideTheme.signalGreen)
                    .frame(width: 6, height: 6)
                Text(DaemonModel.shared == nil ? "Disconnected" : "Connected")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.02))
    }"""
bottom_bar_new = """    private var bottomBar: some View {
        HStack {
            Text("Glide 2.0")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(DaemonModel.shared == nil ? GlideTheme.signalRed : GlideTheme.signalGreen)
                    .frame(width: 6, height: 6)
                Text(DaemonModel.shared == nil ? "Disconnected" : "Connected")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }"""
content = content.replace(bottom_bar_old, bottom_bar_new)

with open(file_path, "w") as f:
    f.write(content)
