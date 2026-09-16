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
                menuBarSection
                preferencesSection
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
                    Text("Icon Style")
                        .font(.subheadline)
                    Spacer()
                    pillPicker(
                        options: [("Standard", "standard"), ("Circle", "circle")],
                        selection: $menuBarIcon
                    )
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
                    pillPicker(
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
            }
            .glassCard()
        }
    }

    // MARK: - Shared Components

    private func pillPicker(options: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.1) { label, value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selection.wrappedValue == value ? Color.white.opacity(0.15) : Color.clear)
                        )
                        .foregroundStyle(selection.wrappedValue == value ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
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
