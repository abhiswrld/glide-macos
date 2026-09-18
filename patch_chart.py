import re

file_path = "/Users/abhinav/Documents/Glide/Glide/HistoryView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Fix the time range picker to not use withAnimation
picker_old = "withAnimation(.spring(duration: 0.3)) { shortTimeRange = range }"
picker_new = "shortTimeRange = range"
content = content.replace(picker_old, picker_new)

# Fix chart X-axis
xaxis_old = """                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }"""
xaxis_new = """                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel() {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.hour())
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }"""
content = content.replace(xaxis_old, xaxis_new)

# Remove .catmullRom interpolation to save performance
content = content.replace(".interpolationMethod(.catmullRom)", "")

with open(file_path, "w") as f:
    f.write(content)
