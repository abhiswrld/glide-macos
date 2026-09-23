import SwiftUI
import ServiceManagement
import GlideCore

struct SettingsView: View {
    @EnvironmentObject var daemon: DaemonModel

    @AppStorage("menuBarIcon") private var menuBarIcon: String = "standard"
    @AppStorage("showTempInMenuBar") private var showTempInMenuBar: Bool = false
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "C"
    @AppStorage("systemNotifications") private var systemNotifications: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("magsafeLEDControlEnabled") private var magsafeLEDControlEnabled: Bool = false
    
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var showActivationSheet = false
    @State private var isProBadgeHovered = false
    
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                menuBarSection
                preferencesSection
                aboutSection
                dangerZoneSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .overlay {
            if showActivationSheet {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showActivationSheet = false }
                    }
                
                LicenseActivationView(onDismiss: {
                    withAnimation { showActivationSheet = false }
                })
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showActivationSheet)
    }



    // MARK: - Menu Bar

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Menu Bar")

            VStack(spacing: 4) {
                // Icon style
                HStack(spacing: 12) {
                    settingsIcon("menubar.rectangle", color: GlideTheme.teal)
                    iconPillPicker(
                        options: [("battery.100", "standard"), ("circle", "circle"), ("battery.100", "vertical")],
                        selection: $menuBarIcon
                    )
                    .disabled(!licenseManager.isPro)
                    .opacity(licenseManager.isPro ? 1.0 : 0.6)
                    
                    if !licenseManager.isPro {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(GlideTheme.pink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(GlideTheme.pink.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.vertical, 6)

                settingsDivider

                // Show percent
                settingsToggleRow(
                    icon: "percent",
                    iconColor: GlideTheme.signalGreen,
                    label: "Show % in Menu Bar",
                    isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "showPercentInMenuBar") },
                        set: { UserDefaults.standard.set($0, forKey: "showPercentInMenuBar") }
                    )
                )

                settingsDivider

                // Menu Only Mode (Hide Dock Icon)
                settingsToggleRow(
                    icon: "dock.rectangle",
                    iconColor: GlideTheme.purple,
                    label: "Menu Bar Only Mode",
                    isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "hideDockIcon") },
                        set: { UserDefaults.standard.set($0, forKey: "hideDockIcon") }
                    )
                )

                settingsDivider

                // Show temp
                settingsToggleRow(
                    icon: "thermometer.medium",
                    iconColor: GlideTheme.orange,
                    label: "Show Temp in Menu Bar",
                    isOn: $showTempInMenuBar
                )
            }
            .glassCard()
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Preferences")

            VStack(spacing: 4) {
                // Temperature unit
                HStack(spacing: 12) {
                    settingsIcon("ruler", color: GlideTheme.blue)
                    Text("Temperature Unit")
                        .font(.subheadline)
                    Spacer()
                    textPillPicker(
                        options: [("°F", "F"), ("°C", "C")],
                        selection: $temperatureUnit
                    )
                }
                .padding(.vertical, 6)

                settingsDivider
                
                // System notifications
                settingsToggleRow(
                    icon: "bell.badge.fill",
                    iconColor: GlideTheme.signalGreen,
                    label: "System Notifications",
                    isOn: $systemNotifications
                )
                
                settingsDivider
                // Launch at Login
                settingsToggleRow(
                    icon: "macwindow",
                    iconColor: GlideTheme.purple,
                    label: "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { on in
                            launchAtLogin = on
                            if #available(macOS 13.0, *) {
                                do {
                                    if on {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                } catch {
                                    print("Launch at login error: \(error)")
                                }
                            }
                        }
                    )
                )
                
                settingsDivider
                
                // MagSafe LED
                settingsToggleRow(
                    icon: "lightbulb.fill",
                    iconColor: GlideTheme.orange,
                    label: "MagSafe LED Control (Beta)",
                    isOn: $magsafeLEDControlEnabled
                )
            }
            .glassCard()
        }
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("About Glide")

            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    settingsIcon("info.circle", color: GlideTheme.blue)
                    Text("Version")
                        .font(.body)
                    Spacer()
                    Text(GlideCore.version)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 14)
                }
                .padding(.vertical, 6)

                settingsDivider

                HStack(spacing: 12) {
                    settingsIcon("star.fill", color: licenseColor)
                    Text("License Status")
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    
                    if case .unverified = licenseManager.status {
                        Button("Activate Pro") {
                            showActivationSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GlideTheme.pink)
                        // .controlSize(.small) removed
                    } else if case .error = licenseManager.status {
                        Button("Activate Pro") {
                            showActivationSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GlideTheme.pink)
                        // .controlSize(.small) removed
                    } else {
                        Group {
                            if isProBadgeHovered {
                                Button("Deactivate") {
                                    Task {
                                        await licenseManager.deactivateLicense()
                                    }
                                }
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            } else {
                                Text(licenseText)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(licenseColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(licenseColor.opacity(0.15))
                                            .shadow(color: licenseColor.opacity(0.4), radius: 6, x: 0, y: 0)
                                    )
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isProBadgeHovered = hovering
                            }
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                
            }
            .glassCard()
            
            Button(action: {
                SparkleManager.shared.checkForUpdates()
            }) {
                Text("Check for Updates")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GlideTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(GlideTheme.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Danger Zone
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Developer & Danger Zone")

            VStack(spacing: 0) {
                Button(action: {
                    uninstallGlide()
                }) {
                    HStack(spacing: 12) {
                        settingsIcon("trash.fill", color: GlideTheme.signalRed)
                        Text("Complete Uninstall")
                            .font(.body)
                            .foregroundStyle(GlideTheme.signalRed)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10) // Reduced padding for this specific card
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GlideTheme.cardStroke, lineWidth: 0.5)
            )
        }
    }
    
    private func uninstallGlide() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Glide?"
        alert.informativeText = "This will remove the background daemon, delete all preferences, and completely trash the Glide app. You will be prompted for your password. The app will close immediately after."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let script = """
            do shell script "/bin/sh -c '(launchctl bootout system/com.abhinav.glide-daemon 2>/dev/null || launchctl unload -w /Library/LaunchDaemons/com.abhinav.glide-daemon.plist 2>/dev/null || true); rm -f /Library/LaunchDaemons/com.abhinav.glide-daemon.plist; rm -f /Library/PrivilegedHelperTools/glide-daemon; rm -rf ~/Library/Preferences/com.abhinav.Glide.plist; rm -rf ~/Library/Preferences/com.abhiswrld.Glide.plist;'" with administrator privileges
            """
            
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    DispatchQueue.main.async {
                        if error == nil {
                            NSApp.terminate(nil)
                        } else {
                            print("Uninstall failed: \\(String(describing: error))")
                        }
                    }
                }
            }
        }
    }
    
    private var licenseText: String {
        switch licenseManager.status {
        case .earlyAdopter: return "Early Adopter"
        case .licensed: return "Pro"
        case .unverified: return "Free"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    private var licenseColor: Color {
        switch licenseManager.status {
        case .earlyAdopter, .licensed: return GlideTheme.pink
        case .error: return .red
        case .unverified: return .secondary
        }
    }

    // MARK: - Shared Components

    private func iconPillPicker(options: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.1) { label, value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    Image(systemName: label)
                        .font(.body.weight(.semibold))
                        .rotationEffect(.degrees(value == "vertical" ? -90 : 0))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection.wrappedValue == value ? Color.white.opacity(0.15) : Color.clear)
                        )
                        .foregroundStyle(selection.wrappedValue == value ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }

    private func textPillPicker(options: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.1) { label, value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection.wrappedValue == value ? Color.white.opacity(0.15) : Color.clear)
                        )
                        .foregroundStyle(selection.wrappedValue == value ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.body.weight(.medium))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func settingsToggleRow(icon: String, iconColor: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(label)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 6)
    }



    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 40)
    }
}
