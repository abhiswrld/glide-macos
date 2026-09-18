//
//  AppDelegate.swift
//  Glide
//
//  Created by Abhinav on 9/14/26.
//

import Cocoa
import SwiftUI
import GlideCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let model = BatteryModel()
    private let daemon = DaemonModel()
    
    private var onboardingWindow: NSWindow?

    // Read user preferences
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "standard"
    @AppStorage("showTempInMenuBar") private var showTempInMenuBar: Bool = false
    @AppStorage("showPercentInMenuBar") private var showPercentInMenuBar: Bool = true
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "C"
    @AppStorage("hideDockIcon") private var hideDockIcon: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        DaemonModel.shared = daemon

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self
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
        UserDefaults.standard.addObserver(self, forKeyPath: "showPercentInMenuBar", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "temperatureUnit", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "hideDockIcon", context: nil)
        
        updateActivationPolicy()
        
        _ = SparkleManager.shared // Initialize Sparkle updater
        
        // Listen for repair requests from PopoverView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRepairNotification),
            name: .glideRepairHelper,
            object: nil
        )
        
        checkDaemonSetup()
    }
    
    private func checkDaemonSetup() {
        let daemonPath = "/Library/PrivilegedHelperTools/glide-daemon"
        let isInstalled = FileManager.default.fileExists(atPath: daemonPath)
        
        NSLog("[Glide] Daemon installed at \\(daemonPath): \\(isInstalled)")
        
        if isInstalled {
            // It's installed on disk, but is it running? We'll assume yes for now, 
            // and the UI will show disconnected if XPC pings fail.
            // (Assuming showMainUI is not a method, we just do nothing here)
        } else {
            NSLog("[Glide] Daemon not found, showing onboarding")
            self.showOnboardingWindow()
        }
    }
    
    @objc private func handleRepairNotification() {
        NSLog("[Glide] Received repair notification")
        repairHelper()
    }
    
    @objc private func repairHelper() {
        NSLog("[Glide] repairHelper() called via NotificationCenter")
        
        // Remove the daemon using osascript
        let script = """
        do shell script "launchctl unload -w /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && rm -f /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && rm -f /Library/PrivilegedHelperTools/glide-daemon" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let err = error {
                NSLog("[Glide] Error removing daemon: \(err)")
            } else {
                NSLog("[Glide] Successfully removed daemon files and unloaded launchd job")
            }
        }
        
        // Close the popover first so it doesn't steal focus from the onboarding window
        if popover.isShown {
            NSLog("[Glide] Closing popover")
            popover.performClose(nil)
        }
        
        // Force-clear any stale onboarding window reference
        NSLog("[Glide] Clearing stale onboarding window (was nil: %d)", onboardingWindow == nil ? 1 : 0)
        onboardingWindow?.close()
        onboardingWindow = nil
        
        // Small delay so the popover fully dismisses before showing the window
        NSLog("[Glide] Scheduling showOnboardingWindow in 0.3s")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            NSLog("[Glide] Async fired, self is nil: %d", self == nil ? 1 : 0)
            self?.showOnboardingWindow()
        }
    }
    
    private func showOnboardingWindow() {
        NSLog("[Glide] showOnboardingWindow() called")
        
        // If window exists and is still visible, just bring it forward
        if let existing = onboardingWindow, existing.isVisible {
            NSLog("[Glide] Existing window is visible, bringing to front")
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Clear any stale reference (e.g. user closed with X button)
        onboardingWindow?.close()
        onboardingWindow = nil
        
        let view = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.daemon.connect()
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.level = .floating  // Ensure it appears above everything
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Drop back to normal level after it's visible so it behaves like a regular window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.level = .normal
        }
    }

    override nonisolated func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        Task { @MainActor in
            if keyPath == "hideDockIcon" {
                self.updateActivationPolicy()
            }
            if let s = self.model.snapshot {
                self.updateStatusItem(s)
            }
        }
    }
    
    private func updateActivationPolicy() {
        let hide = UserDefaults.standard.bool(forKey: "hideDockIcon")
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
        if !hide {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusItem(_ s: BatterySnapshot) {
        guard let button = statusItem?.button else { return }

        let iconStyle = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "standard"
        let showTemp = UserDefaults.standard.bool(forKey: "showTempInMenuBar")
        let showPercent = UserDefaults.standard.bool(forKey: "showPercentInMenuBar")
        let tempUnit = UserDefaults.standard.string(forKey: "temperatureUnit") ?? "C"

        // Set icon based on style
        switch iconStyle {
        case "circle":
            button.image = drawBatteryCircle(percent: s.percent, isCharging: s.isCharging)
        case "vertical":
            button.image = drawBatteryVertical(percent: s.percent, isCharging: s.isCharging)
        default: // "standard"
            button.image = NSImage(systemSymbolName: symbol(for: s), accessibilityDescription: "battery")
            if let img = button.image {
                let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
                button.image = img.withSymbolConfiguration(config)
            }
        }

        // Build title string
        var parts: [String] = []
        
        if showPercent {
            parts.append("\(s.percent)%")
        }

        if showTemp, let tempC = s.temperatureC {
            if tempUnit == "F" {
                parts.append(String(format: "%.1f°F", tempC * 9.0 / 5.0 + 32.0))
            } else {
                parts.append(String(format: "%.1f°C", tempC))
            }
        }

        if parts.isEmpty {
            button.title = ""
        } else {
            button.title = " " + parts.joined(separator: "  ")
        }
    }
    
    private func drawBatteryCircle(percent: Int, isCharging: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
        let trackPath = NSBezierPath(ovalIn: rect)
        
        // Draw track
        NSColor.tertiaryLabelColor.setStroke()
        trackPath.lineWidth = 1.5
        trackPath.stroke()
        
        // Draw progress
        let progressPath = NSBezierPath()
        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = rect.width / 2
        
        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - (CGFloat(percent) / 100.0) * 360.0,
            clockwise: true
        )
        
        progressPath.lineWidth = 1.5
        progressPath.lineCapStyle = .round
        
        NSColor.labelColor.setStroke()
        progressPath.stroke()
        
        if isCharging {
            if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
                let boltSize = NSSize(width: 7, height: 9)
                let boltRect = NSRect(
                    x: center.x - boltSize.width/2,
                    y: center.y - boltSize.height/2,
                    width: boltSize.width,
                    height: boltSize.height
                )
                bolt.draw(in: boltRect)
            }
        }
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }

    private func drawBatteryVertical(percent: Int, isCharging: Bool) -> NSImage {
        let size = NSSize(width: 12, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Battery Body
        let bodyRect = NSRect(x: 1, y: 1, width: 10, height: 13)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 1, yRadius: 1)
        
        // Battery Cap (top)
        let capRect = NSRect(x: 4, y: 14, width: 4, height: 1.5)
        let capPath = NSBezierPath(rect: capRect)
        
        NSColor.tertiaryLabelColor.setStroke()
        bodyPath.lineWidth = 1.0
        bodyPath.stroke()
        
        NSColor.tertiaryLabelColor.setFill()
        capPath.fill()
        
        // Draw progress (bottom up)
        let innerRect = bodyRect.insetBy(dx: 1.5, dy: 1.5)
        let progressHeight = max(0, innerRect.height * CGFloat(percent) / 100.0)
        
        if progressHeight > 0 {
            let progressRect = NSRect(x: innerRect.minX, y: innerRect.minY, width: innerRect.width, height: progressHeight)
            let progressPath = NSBezierPath(roundedRect: progressRect, xRadius: 0.5, yRadius: 0.5)
            NSColor.labelColor.setFill()
            progressPath.fill()
        }
        
        if isCharging {
            if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
                let boltSize = NSSize(width: 6, height: 8)
                let center = NSPoint(x: size.width / 2, y: bodyRect.midY)
                let boltRect = NSRect(
                    x: center.x - boltSize.width/2,
                    y: center.y - boltSize.height/2,
                    width: boltSize.width,
                    height: boltSize.height
                )
                
                if percent > 50 {
                    bolt.isTemplate = false
                    NSColor.windowBackgroundColor.setFill()
                    bolt.draw(in: boltRect, from: .zero, operation: .destinationOut, fraction: 1.0)
                } else {
                    bolt.draw(in: boltRect)
                }
            }
        }
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }

    private func symbol(for s: BatterySnapshot) -> String {
        if s.isCharging { return "battery.100.bolt" }
        
        let level: String
        switch s.percent {
        case ..<13:  level = "battery.0"
        case ..<38:  level = "battery.25"
        case ..<63:  level = "battery.50"
        case ..<88:  level = "battery.75"
        default:     level = "battery.100"
        }
        return level
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
    
    // MARK: - NSPopoverDelegate
    
    func popoverWillShow(_ notification: Notification) {
        model.setUIVisibility(true)
    }
    
    func popoverDidClose(_ notification: Notification) {
        model.setUIVisibility(false)
    }
}
import Foundation
import UserNotifications

@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[Glide] Notification authorization error: \(error.localizedDescription)")
            } else {
                NSLog("[Glide] Notification authorization granted: \(granted)")
            }
        }
    }
    
    func sendNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        let isEnabled = UserDefaults.standard.bool(forKey: "systemNotifications")
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[Glide] Failed to send notification: \(error.localizedDescription)")
            } else {
                NSLog("[Glide] Notification sent: \(title)")
            }
        }
    }
}
