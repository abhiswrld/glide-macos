//
//  AppDelegate.swift
//  Glide
//
//  Created by Abhinav on 9/14/26.
//

import AppKit
import SwiftUI
import GlideCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let model = BatteryModel()
    private let daemon = DaemonModel()

    // Read user preferences
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "standard"
    @AppStorage("showTempInMenuBar") private var showTempInMenuBar: Bool = false
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "C"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        DaemonModel.shared = daemon

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(model).environmentObject(daemon)
        )

        model.onUpdate = { [weak self] snapshot in
            self?.updateStatusItem(snapshot)
        }
        model.start()

        // Observe settings changes to update menu bar immediately
        UserDefaults.standard.addObserver(self, forKeyPath: "menuBarIcon", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showTempInMenuBar", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "temperatureUnit", context: nil)
    }

    override nonisolated func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        Task { @MainActor in
            if let s = self.model.snapshot {
                self.updateStatusItem(s)
            }
        }
    }

    private func updateStatusItem(_ s: BatterySnapshot) {
        guard let button = statusItem?.button else { return }

        let iconStyle = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "standard"
        let showTemp = UserDefaults.standard.bool(forKey: "showTempInMenuBar")
        let tempUnit = UserDefaults.standard.string(forKey: "temperatureUnit") ?? "C"

        // Set icon based on style
        switch iconStyle {
        case "circle":
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "battery")
            // Tint based on charging state
            if let img = button.image {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                button.image = img.withSymbolConfiguration(config)
            }
        default: // "standard"
            button.image = NSImage(systemSymbolName: symbol(for: s), accessibilityDescription: "battery")
        }

        // Build title string
        var title = "\(s.percent)%"

        if showTemp, let tempC = s.temperatureC {
            let tempStr: String
            if tempUnit == "F" {
                tempStr = String(format: "%.0f°F", tempC * 9.0 / 5.0 + 32.0)
            } else {
                tempStr = String(format: "%.0f°C", tempC)
            }
            title += "  \(tempStr)"
        }

        button.title = " \(title)"
    }

    private func symbol(for s: BatterySnapshot) -> String {
        let level: String
        switch s.percent {
        case ..<13:  level = "battery.0"
        case ..<38:  level = "battery.25"
        case ..<63:  level = "battery.50"
        case ..<88:  level = "battery.75"
        default:     level = "battery.100"
        }
        guard s.isCharging,
              NSImage(systemSymbolName: "\(level).bolt", accessibilityDescription: nil) != nil
        else { return level }
        return "\(level).bolt"
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
