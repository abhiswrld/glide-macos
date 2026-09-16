import SwiftUI
import GlideCore

struct SettingsView: View {
    @EnvironmentObject var daemon: DaemonModel

    @AppStorage("menuBarIcon") private var menuBarIcon: String = "standard"
    @AppStorage("showTempInMenuBar") private var showTempInMenuBar: Bool = false
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "C"
    @AppStorage("systemNotifications") private var systemNotifications: Bool = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                chargingFeaturesSection
                menuBarSection
                preferencesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Charging Features (Coming Soon)

    private var chargingFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Charging Features")

            VStack(spacing: 0) {
                comingSoonRow(
                    icon: "wind",
                    iconColor: GlideTheme.blue,
                    label: "Sailing Mode",
                    subtitle: "Discharge to 75% before recharging"
                )
                settingsDivider
                comingSoonRow(
                    icon: "thermometer.sun.fill",
                    iconColor: GlideTheme.orange,
                    label: "Heat Protection",
                    subtitle: "Pause charging above 37°C"
                )
                settingsDivider
                comingSoonRow(
                    icon: "minus.circle",
                    iconColor: GlideTheme.signalRed,
                    label: "Force Discharge",
                    subtitle: "Run entirely on battery down to 20%"
                )
                settingsDivider
                comingSoonRow(
                    icon: "arrow.triangle.2.circlepath.circle",
                    iconColor: Color.purple,
                    label: "Calibration Cycle",
                    subtitle: "100% → 10% → back to limit"
                )
            }
            .glassCard()
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
                    Text("Icon Style")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $menuBarIcon) {
                        Text("Standard").tag("standard")
                        Text("Circle").tag("circle")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                .padding(.vertical, 6)

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
                    Picker("", selection: $temperatureUnit) {
                        Text("°F").tag("F")
                        Text("°C").tag("C")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
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
            }
            .glassCard()
        }
    }

    // MARK: - Shared Components

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

    private func comingSoonRow(icon: String, iconColor: Color, label: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Soon")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
        .opacity(0.6)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 40)
    }
}
