# Glide v2 — devlog

## Session 1 — skeleton
- XcodeGen project: Glide app + glide-daemon + GlideCore local package
- macOS 15+, Apple Silicon, ad-hoc signed
- Bundle ID: com.abhiswrld.Glide

## Session 2 — menu bar + battery reads
- NSStatusItem + popover, SwiftUI content, LSUIElement (no dock icon)
- BatteryReader in GlideCore: charge, cycles, health, temp, watts via AppleSmartBattery
- raw-key debug dump in the popover (stays until the daemon lands)
