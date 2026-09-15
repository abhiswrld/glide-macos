# Glide v2 — devlog

## Session 1 — skeleton
- XcodeGen project: Glide app + glide-daemon + GlideCore local package
- macOS 15+, Apple Silicon, ad-hoc signed
- Bundle ID: com.abhiswrld.Glide

## Session 2 — menu bar + battery reads
- NSStatusItem + popover, SwiftUI content, LSUIElement (no dock icon)
- BatteryReader in GlideCore: charge, cycles, health, temp, watts via AppleSmartBattery
- raw-key debug dump in the popover (stays until the daemon lands)

## Session — got the lever to work
- ChargeLimiter in GlideCore: CFPreferences write + darwin doorbell, no shell-outs
- validated 60/85/90 set+enforce from our own binary; local validation rejects non-detents (73)
- next: launchd daemon + XPC, then slider in popover
