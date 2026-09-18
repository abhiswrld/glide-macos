import re

file_path = "/Users/abhinav/Documents/Glide/Glide/HistoryView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Make a new struct IsolatedShortTermChart
new_struct = """

struct IsolatedShortTermChart: View, Equatable {
    let entries: [ShortTermBatteryEntry]

    static func == (lhs: IsolatedShortTermChart, rhs: IsolatedShortTermChart) -> Bool {
        if lhs.entries.count != rhs.entries.count { return false }
        return true // Just approximation to prevent frequent redraws
    }

    var body: some View {
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
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
"""

content = content + new_struct

# replace Chart(...) ... .chartXAxis { ... } with IsolatedShortTermChart(entries: filteredShortTermEntries).equatable()
chart_regex = r"Chart\(filteredShortTermEntries\).*?\.chartXAxis \{.*?\n                \}"
content = re.sub(chart_regex, "IsolatedShortTermChart(entries: filteredShortTermEntries)\n                .equatable()", content, flags=re.DOTALL)

with open(file_path, "w") as f:
    f.write(content)
