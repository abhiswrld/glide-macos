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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        DaemonModel.shared = daemon

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 540)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(model).environmentObject(daemon)
        )

        model.onUpdate = { [weak self] snapshot in
            self?.updateStatusItem(snapshot)
        }
        model.start()
    }

    private func updateStatusItem(_ s: BatterySnapshot) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: symbol(for: s), accessibilityDescription: "battery")
        button.title = "\(s.percent)%"
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
