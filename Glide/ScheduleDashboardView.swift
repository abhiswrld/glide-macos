import SwiftUI

struct ScheduleDashboardView: View {
    @ObservedObject private var smartCharging = SmartChargingModel.shared
    @State private var selectedWeekday: Int = 2 // Default Monday
    
    let days = [
        (2, "MON"),
        (3, "TUE"),
        (4, "WED"),
        (5, "THU"),
        (6, "FRI"),
        (7, "SAT"),
        (1, "SUN")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("Smart Charging Routine")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 24)
                
                Text("Fine-tune your week to power through the day with our intelligent charging.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 24)
            
            // Pill Picker
            HStack(spacing: 12) {
                ForEach(days, id: \.0) { (weekday, shortName) in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedWeekday = weekday
                        }
                    } label: {
                        Text(shortName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(selectedWeekday == weekday ? .white : .secondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(selectedWeekday == weekday ? GlideTheme.purple : Color.white.opacity(0.05))
                            )
                            .shadow(color: selectedWeekday == weekday ? GlideTheme.purple.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            
            // Main Content
            VStack(alignment: .leading, spacing: 0) {
                let fullName = Calendar.current.weekdaySymbols[selectedWeekday - 1].uppercased()
                
                Text("\(fullName)'S ROUTINE")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(GlideTheme.purple)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 12) {
                        let schedules = smartCharging.manualSchedule[selectedWeekday] ?? []
                        
                        if schedules.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(GlideTheme.purple)
                                Text("No custom routine set.")
                                    .font(.title3.weight(.semibold))
                                Text("Glide will automatically learn your habits and predict when you unplug.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(schedules.sorted(by: { $0.timeSinceMidnight < $1.timeSinceMidnight })) { entry in
                                RoutineBlockView(weekday: selectedWeekday, entry: entry, manualSchedule: $smartCharging.manualSchedule)
                            }
                        }
                        
                        Button {
                            addSchedule()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Time Block")
                            }
                            .font(.body.weight(.bold))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(minWidth: 450, idealWidth: 550, maxWidth: .infinity, minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .onChange(of: smartCharging.manualSchedule) { _ in
            smartCharging.saveManualSchedule()
        }
    }
    
    private func addSchedule() {
        let newEntry = ManualScheduleEntry(timeSinceMidnight: 8 * 3600, chargeLevel: 100) // Default 8:00 AM, 100%
        if smartCharging.manualSchedule[selectedWeekday] != nil {
            smartCharging.manualSchedule[selectedWeekday]?.append(newEntry)
        } else {
            smartCharging.manualSchedule[selectedWeekday] = [newEntry]
        }
    }
}

struct RoutineBlockView: View {
    let weekday: Int
    let entry: ManualScheduleEntry
    @Binding var manualSchedule: [Int: [ManualScheduleEntry]]
    
    @State private var isEditing: Bool = false
    @State private var time: Date = Date()
    @State private var limit: Double = 100
    
    private var timeHour: Binding<Int> {
        Binding(
            get: {
                var h = Calendar.current.component(.hour, from: time)
                if h == 0 { return 12 }
                if h > 12 { return h - 12 }
                return h
            },
            set: { newHour in
                let currentAmPm = Calendar.current.component(.hour, from: time) >= 12 ? 1 : 0
                var h = newHour
                if h == 12 { h = 0 }
                let finalHour = h + (currentAmPm * 12)
                let mins = Calendar.current.component(.minute, from: time)
                if let d = Calendar.current.date(bySettingHour: finalHour, minute: mins, second: 0, of: time) {
                    time = d
                }
            }
        )
    }
    
    private var timeMinute: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: time) },
            set: { newMin in
                let h = Calendar.current.component(.hour, from: time)
                if let d = Calendar.current.date(bySettingHour: h, minute: newMin, second: 0, of: time) {
                    time = d
                }
            }
        )
    }
    
    private var timeAmPm: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: time) >= 12 ? 1 : 0 },
            set: { newAmPm in
                var h = Calendar.current.component(.hour, from: time)
                if newAmPm == 1 && h < 12 { h += 12 }
                if newAmPm == 0 && h >= 12 { h -= 12 }
                let mins = Calendar.current.component(.minute, from: time)
                if let d = Calendar.current.date(bySettingHour: h, minute: mins, second: 0, of: time) {
                    time = d
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing.toggle()
                }
            } label: {
                HStack {
                    Text(formattedTime(entry.timeSinceMidnight))
                        .font(.title3.weight(.bold).monospacedDigit())
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Text("\(entry.chargeLevel)%")
                        .font(.title3.weight(.bold).monospacedDigit())
                    
                    Image(systemName: "battery.100")
                        .foregroundStyle(GlideTheme.signalGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(isEditing ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
            }
            .buttonStyle(.plain)
            
            if isEditing {
                VStack(spacing: 16) {
                    HStack {
                        Text("Finish Charging By")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        HStack(spacing: 4) {
                            Picker("", selection: timeHour) {
                                ForEach(1...12, id: \.self) { h in Text("\(h)").tag(h) }
                            }
                            .frame(width: 55)
                            
                            Text(":")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: timeMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                            }
                            .frame(width: 55)
                            
                            Picker("", selection: timeAmPm) {
                                Text("AM").tag(0)
                                Text("PM").tag(1)
                            }
                            .frame(width: 55)
                        }
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("Charge Limit")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Slider(value: $limit, in: 20...100, step: 5)
                            .frame(width: 150)
                        Text("\(Int(limit))%")
                            .font(.body.monospacedDigit().bold())
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            deleteEntry()
                        } label: {
                            Text("Delete")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            time = today.addingTimeInterval(entry.timeSinceMidnight)
            limit = Double(entry.chargeLevel)
        }
        .onChange(of: time) { _ in updateEntry() }
        .onChange(of: limit) { _ in updateEntry() }
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let date = today.addingTimeInterval(interval)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func updateEntry() {
        guard let idx = manualSchedule[weekday]?.firstIndex(where: { $0.id == entry.id }) else { return }
        
        let cal = Calendar.current
        let start = cal.startOfDay(for: time)
        let timeSinceMidnight = time.timeIntervalSince(start)
        
        manualSchedule[weekday]?[idx].timeSinceMidnight = timeSinceMidnight
        manualSchedule[weekday]?[idx].chargeLevel = Int(limit)
    }
    
    private func deleteEntry() {
        manualSchedule[weekday]?.removeAll(where: { $0.id == entry.id })
        if manualSchedule[weekday]?.isEmpty == true {
            manualSchedule.removeValue(forKey: weekday)
        }
    }
}
