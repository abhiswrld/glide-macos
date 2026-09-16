import SwiftUI
import AppKit
import GlideCore

// MARK: - Theme

enum GlideTheme {
    static let signalGreen  = Color(nsColor: .systemGreen)
    static let signalRed    = Color(nsColor: .systemRed)
    static let orange       = Color(nsColor: .systemOrange)
    static let blue         = Color(nsColor: .systemBlue)
    static let teal         = Color(nsColor: .systemTeal)
    static let pink         = Color(nsColor: .systemPink)

    static let cardFill     = Color.white.opacity(0.06)
    static let cardStroke   = Color.white.opacity(0.10)
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GlideTheme.cardStroke, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

// MARK: - PopoverView

enum GlideTab: String, CaseIterable {
    case battery, history, settings

    var icon: String {
        switch self {
        case .battery: return "bolt.fill"
        case .history: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

struct PopoverView: View {
    @EnvironmentObject var model: BatteryModel
    @EnvironmentObject var daemon: DaemonModel

    @State private var draggingLimit: Double?
    @State private var selectedTab: GlideTab = .battery
    @State private var draggingSailingLimit: Double?

    @AppStorage("sailingEnabled") private var sailingEnabled: Bool = false
    @AppStorage("sailingLowerLimit") private var sailingLowerLimit: Int = 75
    @AppStorage("isSailing") private var isSailing: Bool = false
    @AppStorage("heatProtectionEnabled") private var heatProtectionEnabled: Bool = false
    @AppStorage("forceDischargeEnabled") private var forceDischargeEnabled: Bool = false
    @AppStorage("primaryChargeLimit") private var primaryChargeLimit: Int = 80
    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                switch selectedTab {
                case .battery:
                    batteryTab
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .frame(width: 320, height: 520)
        .preferredColorScheme(.dark)
        .onAppear { daemon.connect() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(GlideTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedTab = tab }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear, lineWidth: 0.5)
                        )
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    // MARK: - Battery Tab

    private var batteryTab: some View {
        ScrollView(showsIndicators: false) {
            if let s = model.snapshot {
                VStack(alignment: .leading, spacing: 14) {
                    header(s)
                    limitSection(s)
                    chargingFeaturesSection
                    statsSection(s)
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            } else {
                VStack {
                    Spacer()
                    ProgressView("Reading battery…")
                        .controlSize(.small)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 440)
            }
        }
    }

    // MARK: - Header

    private func header(_ s: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(s.percent)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: s.percent)
                    Text("%")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stateLabel(s)
            }
            batteryBar(s)
        }
    }

    @ViewBuilder
    private func stateLabel(_ s: BatterySnapshot) -> some View {
        let targetLimit = primaryChargeLimit
        let isEffectivelyCharging = s.isCharging || (s.isPluggedIn && s.percent < targetLimit)

        Group {
            if isSailing {
                statePill("Sailing", icon: "wind", color: GlideTheme.blue)
            } else if isEffectivelyCharging {
                statePill("Charging", icon: "bolt.fill", color: GlideTheme.signalGreen, pulse: true)
            } else if s.isPluggedIn && s.percent >= targetLimit {
                statePill("Holding", icon: "pause.fill", color: GlideTheme.orange)
            } else if s.isFull {
                statePill("Full", icon: "checkmark", color: .secondary)
            } else {
                statePill("On Battery", icon: batteryIcon(s), color: .secondary)
            }
        }
    }

    private func statePill(_ text: String, icon: String, color: Color, pulse: Bool = false) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .symbolEffect(.pulse, options: .repeating, isActive: pulse)
    }

    private func batteryIcon(_ s: BatterySnapshot) -> String {
        switch s.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }

    private func batteryBar(_ s: BatterySnapshot) -> some View {
        let targetLimit = primaryChargeLimit
        let isEffectivelyCharging = s.isCharging || (s.isPluggedIn && s.percent < targetLimit)
        
        let limitGradient = LinearGradient(
            stops: [
                Gradient.Stop(color: GlideTheme.signalGreen, location: 0.0),
                Gradient.Stop(color: GlideTheme.signalGreen, location: 0.6),
                Gradient.Stop(color: GlideTheme.orange, location: 0.8),
                Gradient.Stop(color: GlideTheme.signalRed, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )



        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 12)

                    if isEffectivelyCharging {
                        limitGradient
                            .mask(
                                ZStack(alignment: .leading) {
                                    Capsule().frame(width: max(0, geo.size.width * CGFloat(s.percent) / 100))
                                    Color.clear
                                }
                            )
                            .frame(height: 12)
                            .animation(.spring(duration: 0.5), value: s.percent)
                    } else {
                        Capsule()
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: max(0, geo.size.width * CGFloat(s.percent) / 100), height: 12)
                            .animation(.spring(duration: 0.5), value: s.percent)
                    }

                    let limit = primaryChargeLimit
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3, height: 18)
                        .offset(x: geo.size.width * CGFloat(limit) / 100 - 1.5)
                        .animation(.spring(duration: 0.4), value: limit)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
            .frame(height: 18)

            HStack {
                if let tr = model.timeRemaining {
                    Text(tr)
                } else {
                    Text(s.isPluggedIn ? "Power Adapter" : "Battery")
                }
                Spacer()
                let limit = primaryChargeLimit
                Text("Limit \(limit)%")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Charge Limit

    private func limitSection(_ s: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let limit = primaryChargeLimit
            HStack {
                Label("Charge Limit", systemImage: "battery.100.bolt")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(limit)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(GlideTheme.signalGreen)
            }

            if daemon.limit != nil {
                ThickSlider(
                    value: Binding(
                        get: { draggingLimit ?? Double(limit) },
                        set: { draggingLimit = $0 }
                    ),
                    range: 60...100,
                    step: 5,
                    fillStyle: AnyShapeStyle(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: GlideTheme.signalGreen, location: 0.0),
                                Gradient.Stop(color: GlideTheme.signalGreen, location: 0.6),
                                Gradient.Stop(color: GlideTheme.orange, location: 0.8),
                                Gradient.Stop(color: GlideTheme.signalRed, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ),
                    onEditingChanged: { editing in
                        if !editing, let v = draggingLimit {
                            draggingLimit = nil
                            let newLimit = Int(v)
                            primaryChargeLimit = newLimit
                            daemon.setLimit(newLimit)
                        }
                    }
                )

                // Preset capsules
                HStack(spacing: 6) {
                    ForEach([60, 70, 80, 90, 100], id: \.self) { p in
                        Button { primaryChargeLimit = p; daemon.setLimit(p) } label: {
                            Text("\(p)%")
                                .font(.caption2.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(p == primaryChargeLimit ? Color.white.opacity(0.15) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(p == primaryChargeLimit ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
                                )
                                .foregroundStyle(p == primaryChargeLimit ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Label("Daemon offline", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(GlideTheme.signalRed)
            }

            if let err = daemon.lastError {
                Text(err).font(.caption2).foregroundStyle(GlideTheme.signalRed)
            }
        }
        .glassCard()
    }

    // MARK: - Stats

    private func statsSection(_ s: BatterySnapshot) -> some View {
        VStack(spacing: 0) {
            statRow(icon: "arrow.triangle.2.circlepath",
                    iconColor: GlideTheme.teal,
                    label: "Cycle Count",
                    value: "\(s.cycleCount)")
            statDivider
            statRow(icon: "heart.fill",
                    iconColor: GlideTheme.pink,
                    label: "Battery Health",
                    value: s.healthPercent.map { "\($0)%" } ?? "—")
            statDivider
            statRow(icon: "thermometer.medium",
                    iconColor: GlideTheme.orange,
                    label: "Temperature",
                    value: s.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—")
            statDivider
            statRow(icon: "bolt.fill",
                    iconColor: GlideTheme.signalGreen,
                    label: "Power Draw",
                    value: s.watts.map { String(format: "%.1f W", $0) } ?? "—")
        }
        .glassCard()
    }

    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 40)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Glide 2.0")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(daemon.limit != nil ? GlideTheme.signalGreen : GlideTheme.signalRed)
                    .frame(width: 5, height: 5)
                Text(daemon.limit != nil ? "Connected" : "Disconnected")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    // MARK: - Charging Features

    private var chargingFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHARGING FEATURES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                // Sailing Mode
                featureToggleRow(
                    icon: "wind",
                    iconColor: GlideTheme.blue,
                    label: "Sailing Mode",
                    subtitle: "Discharge before recharging",
                    isOn: $sailingEnabled
                )
                
                if sailingEnabled {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.leading, 40)

                    
                    HStack {
                        Spacer().frame(width: 40)
                        
                        let userLimit = primaryChargeLimit
                        let opt1 = max(20, userLimit - 5)
                        let opt2 = max(20, userLimit - 10)
                        
                        HStack(spacing: 0) {
                            ForEach([opt1, opt2], id: \.self) { opt in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        sailingLowerLimit = opt
                                    }
                                } label: {
                                    Text("\(opt)%")
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(sailingLowerLimit == opt ? GlideTheme.blue : Color.clear)
                                        )
                                        .foregroundStyle(sailingLowerLimit == opt ? .white : .secondary)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 40)

                featureToggleRow(
                    icon: "thermometer.sun.fill",
                    iconColor: GlideTheme.orange,
                    label: "Heat Protection",
                    subtitle: "Pause charging above 37°C",
                    isOn: $heatProtectionEnabled
                )
                
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 40)

                featureToggleRow(
                    icon: "minus.circle",
                    iconColor: GlideTheme.signalRed,
                    label: "Force Discharge",
                    subtitle: "Run entirely on battery down to 20%",
                    isOn: $forceDischargeEnabled
                )
            }
            .glassCard()
        }
    }
    
    private func featureToggleRow(icon: String, iconColor: Color, label: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Helper Views

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ThickSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var fillStyle: AnyShapeStyle
    var onEditingChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let pct = max(0, min(1, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Rectangle().fill(fillStyle)
                    .mask(
                        ZStack(alignment: .leading) {
                            Capsule().frame(width: max(20, geo.size.width * CGFloat(pct)))
                            Color.clear
                        }
                    )
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onEditingChanged(true)
                        let p = max(0, min(1, drag.location.x / geo.size.width))
                        let raw = range.lowerBound + Double(p) * (range.upperBound - range.lowerBound)
                        value = min(range.upperBound, max(range.lowerBound, round(raw / step) * step))
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 28)
    }
}
