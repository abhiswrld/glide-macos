import SwiftUI
import Charts
import GlideCore

struct HistoryView: View {
    @EnvironmentObject var model: BatteryModel

    @State private var timeRange: TimeRange = .sixMonths

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

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.rawValue) { range in
                Button {
                    withAnimation(.spring(duration: 0.3)) { timeRange = range }
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
            HStack {
                Label("Battery Health", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = filteredEntries.last?.healthPercent {
                    Text("\(latest)%")
                        .font(.subheadline.weight(.bold))
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
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.pink.opacity(0.8), GlideTheme.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Health", entry.healthPercent)
                    )
                    .interpolationMethod(.catmullRom)
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
            HStack {
                Label("Cycle Count", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = filteredEntries.last?.cycleCount {
                    Text("\(latest)")
                        .font(.subheadline.weight(.bold))
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
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.teal.opacity(0.8), GlideTheme.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Cycles", entry.cycleCount)
                    )
                    .interpolationMethod(.catmullRom)
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
