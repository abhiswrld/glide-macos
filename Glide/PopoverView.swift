import SwiftUI
import GlideCore

struct PopoverView: View {
    @EnvironmentObject var model: BatteryModel
    @EnvironmentObject var daemon: DaemonModel

    @State private var draggingLimit: Double?

    var body: some View {
        ScrollView {
            if let s = model.snapshot {
                VStack(alignment: .leading, spacing: 14) {
                    header(s)
                    Divider()
                    limitSection
                    Divider()
                    statGrid(s)
                    Divider()
                    debugSection(s)
                }
                .padding(18)
            } else {
                ProgressView("reading battery…").padding(30)
            }
        }
        .frame(width: 340, height: 540)
        .preferredColorScheme(.dark)
        .onAppear { daemon.connect() }
    }

    private var limitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CHARGE LIMIT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let limit = daemon.limit {
                    Text("\(limit)%").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.mint)
                } else {
                    Label("daemon offline", systemImage: "bolt.slash")
                        .font(.caption.weight(.medium)).foregroundStyle(.orange)
                }
            }

            if let limit = daemon.limit {
                Slider(
                    value: Binding(
                        get: { draggingLimit ?? Double(limit) },
                        set: { draggingLimit = $0 }
                    ),
                    in: 60...100,
                    step: 5
                ) { editing in
                    if !editing, let v = draggingLimit {
                        daemon.setLimit(Int(v))
                        draggingLimit = nil
                    }
                }
                HStack {
                    Text("60").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    ForEach([80, 85, 90, 100], id: \.self) { preset in
                        Button("\(preset)%") { daemon.setLimit(preset) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(preset == daemon.limit ? .mint : .secondary)
                    }
                    Spacer()
                    Text("100").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let err = daemon.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private func header(_ s: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(s.percent)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("%").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if s.isCharging { Image(systemName: "bolt.fill").foregroundStyle(.mint) }
            }
            Text(stateLine(s)).font(.subheadline.weight(.medium))
        }
    }

    private func stateLine(_ s: BatterySnapshot) -> String {
        var parts: [String] = []
        if s.isFull { parts.append("full") }
        else if s.isCharging { parts.append("charging") }
        else if s.isPluggedIn { parts.append("on AC · holding") }
        else { parts.append("on battery") }
        if let t = s.temperatureC { parts.append(String(format: "%.1f°C", t)) }
        return parts.joined(separator: " · ")
    }

    private func statGrid(_ s: BatterySnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            stat("cycles", "\(s.cycleCount)")
            stat("health", s.healthPercent.map { "\($0)%" } ?? "—")
            stat("temp", s.temperatureC.map { String(format: "%.1f°C", $0) } ?? "—")
            stat("power", s.watts.map { String(format: "%.2f W", $0) } ?? "—")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func debugSection(_ s: BatterySnapshot) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(s.raw.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(s.raw[key] ?? 0)")
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
            }
            .padding(.vertical, 6)
        } label: {
            Text("raw AppleSmartBattery (debug)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
}
