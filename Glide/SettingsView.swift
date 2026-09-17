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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                menuBarSection
                preferencesSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }



    // MARK: - Menu Bar

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Menu Bar")

            VStack(spacing: 0) {
                // Icon style
                HStack(spacing: 12) {
                    settingsIcon("menubar.rectangle", color: GlideTheme.teal)
                    iconPillPicker(
                        options: [("battery.100", "standard"), ("circle", "circle"), ("battery.100", "vertical")],
                        selection: $menuBarIcon
                    )
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
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Preferences")

            VStack(spacing: 0) {
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("About Glide")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    settingsIcon("info.circle", color: GlideTheme.blue)
                    Text("Version")
                        .font(.subheadline)
                    Spacer()
                    Text(GlideCore.version)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                settingsDivider

                HStack(spacing: 12) {
                    settingsIcon("star.fill", color: GlideTheme.pink)
                    Text("License Status")
                        .font(.subheadline)
                    Spacer()
                    Text(licenseText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GlideTheme.pink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(GlideTheme.pink.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 6)
            }
            .glassCard()

            // Check for Updates in its own centered bubble
            Button {
                SparkleManager.shared.checkForUpdates()
            } label: {
                HStack {
                    Spacer()
                    Text("Check for Updates")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GlideTheme.blue)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var licenseText: String {
        switch LicenseManager.shared.status {
        case .earlyAdopter: return "Early Adopter" // Emojis removed!
        case .licensed: return "Pro"
        case .trial(let days): return "\(days) days left"
        case .expired: return "Expired"
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
