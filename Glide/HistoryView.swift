import SwiftUI
import Charts
import GlideCore

struct HistoryView: View {
    @EnvironmentObject var model: BatteryModel

    @AppStorage("historyTimeRange") private var timeRange: TimeRange = .sixMonths
    @AppStorage("shortHistoryTimeRange") private var shortTimeRange: ShortTimeRange = .sixHours

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


    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var days: Int? {
            switch self {
            case .oneMonth: return 30
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return nil
            }
        }
    }

    private var filteredEntries: [BatteryHistoryEntry] {
        let entries = model.history
        guard let days = timeRange.days else { return entries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Time range picker

                HStack {
                    Spacer()
                    shortTimeRangePicker
                    Spacer()
                }
                
                shortTermChart
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    Spacer()
                    timeRangePicker
                    Spacer()
                }

                healthChart
                cycleChart
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }


    // MARK: - Short Time Range Picker

    private var shortTimeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(ShortTimeRange.allCases, id: \.rawValue) { range in
                Button {
                    shortTimeRange = range
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
                    Text("\(latest)%")
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
                IsolatedShortTermChart(entries: filteredShortTermEntries, rangeHours: shortTimeRange.hours)
                .equatable()
                .frame(height: 140)
                .glassCard()
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.rawValue) { range in
                Button {
                    timeRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(timeRange == range ? Color.white.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(timeRange == range ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
                        )
                        .foregroundStyle(timeRange == range ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }

    // MARK: - Health Chart

    private var healthChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label("Battery Health", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = filteredEntries.last?.healthPercent {
                    Text("\(latest)%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GlideTheme.pink)
                }
            }

            if filteredEntries.isEmpty {
                emptyState
            } else {
                Chart(filteredEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Health", entry.healthPercent)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.pink.opacity(0.8), GlideTheme.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    if filteredEntries.count == 1 {
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Health", entry.healthPercent)
                        )
                        .foregroundStyle(GlideTheme.pink)
                    }

                    AreaMark(
                        x: .value("Date", entry.date),
                        yStart: .value("Min", 70),
                        yEnd: .value("Health", entry.healthPercent)
                    )
                    
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.pink.opacity(0.2), GlideTheme.pink.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 70...100)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [75, 85, 95]) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .frame(height: 140)
            }
        }
        .glassCard()
    }

    // MARK: - Cycle Chart

    private var cycleChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label("Cycle Count", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = filteredEntries.last?.cycleCount {
                    Text("\(latest)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GlideTheme.teal)
                }
            }

            if filteredEntries.isEmpty {
                emptyState
            } else {
                Chart(filteredEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Cycles", entry.cycleCount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.teal.opacity(0.8), GlideTheme.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    if filteredEntries.count == 1 {
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Cycles", entry.cycleCount)
                        )
                        .foregroundStyle(GlideTheme.teal)
                    }

                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Cycles", entry.cycleCount)
                    )
                    
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.teal.opacity(0.2), GlideTheme.teal.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .frame(height: 140)
            }
        }
        .glassCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Not enough data yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Glide logs once per day")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}


struct IsolatedShortTermChart: View, Equatable {
    let entries: [ShortTermBatteryEntry]
    let rangeHours: Int

    static func == (lhs: IsolatedShortTermChart, rhs: IsolatedShortTermChart) -> Bool {
        return lhs.entries.count == rhs.entries.count &&
               lhs.rangeHours == rhs.rangeHours &&
               lhs.entries.last?.date == rhs.entries.last?.date
    }

    var body: some View {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -rangeHours, to: now) ?? now

        Chart(entries) { entry in
            LineMark(
                x: .value("Time", entry.date),
                y: .value("Level", entry.percent)
            )
            .foregroundStyle(GlideTheme.signalGreen)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("Time", entry.date),
                y: .value("Level", entry.percent)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [GlideTheme.signalGreen.opacity(0.2), GlideTheme.signalGreen.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXScale(domain: startDate...now)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                AxisValueLabel {
                    Text("\(value.as(Int.self) ?? 0)%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisValueLabel() {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
