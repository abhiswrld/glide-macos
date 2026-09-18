import re

file_path = "/Users/abhinav/Documents/Glide/Glide/HistoryView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Add ShortTimeRange enum and State
new_state = """
    @State private var shortTimeRange: ShortTimeRange = .twelveHours

    enum ShortTimeRange: String, CaseIterable {
        case twoHours = "2H"
        case sixHours = "6H"
        case twelveHours = "12H"

        var hours: Int {
            switch self {
            case .twoHours: return 2
            case .sixHours: return 6
            case .twelveHours: return 12
            }
        }
    }

    private var filteredShortTermEntries: [ShortTermBatteryEntry] {
        let entries = model.shortTermHistory
        let cutoff = Calendar.current.date(byAdding: .hour, value: -shortTimeRange.hours, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }
"""
content = content.replace("    @State private var timeRange: TimeRange = .sixMonths", "    @State private var timeRange: TimeRange = .sixMonths\n" + new_state)

# Add shortTermPicker and shortTermChart to body
body_str = """
                HStack {
                    Spacer()
                    shortTimeRangePicker
                    Spacer()
                }
                
                shortTermChart
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
"""
content = content.replace("                HStack {\n                    Spacer()\n                    timeRangePicker\n                    Spacer()\n                }", body_str + "                    Spacer()\n                    timeRangePicker\n                    Spacer()\n                }")

# Add the views
views_str = """
    // MARK: - Short Time Range Picker

    private var shortTimeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(ShortTimeRange.allCases, id: \\.rawValue) { range in
                Button {
                    withAnimation(.spring(duration: 0.3)) { shortTimeRange = range }
                } label: {
                    Text(range.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(shortTimeRange == range ? Color.white.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(shortTimeRange == range ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
                        )
                        .foregroundStyle(shortTimeRange == range ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    // MARK: - Short Term Chart
    
    private var shortTermChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label("Battery Level", systemImage: "bolt.batteryblock.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = filteredShortTermEntries.last?.percent {
                    Text("\\(latest)%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GlideTheme.signalGreen)
                }
            }

            if filteredShortTermEntries.isEmpty {
                VStack {
                    Spacer()
                    Text("Gathering Data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .glassCard()
            } else {
                Chart(filteredShortTermEntries) { entry in
                    LineMark(
                        x: .value("Time", entry.date),
                        y: .value("Level", entry.percent)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(GlideTheme.signalGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    
                    AreaMark(
                        x: .value("Time", entry.date),
                        y: .value("Level", entry.percent)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.signalGreen.opacity(0.2), GlideTheme.signalGreen.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            Text("\\(value.as(Int.self) ?? 0)%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 140)
                .glassCard()
            }
        }
    }
"""

content = content.replace("    // MARK: - Time Range Picker", views_str + "\n    // MARK: - Time Range Picker")

with open(file_path, "w") as f:
    f.write(content)
