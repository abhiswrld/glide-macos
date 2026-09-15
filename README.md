# Glide

A native macOS utility that protects long-term battery health through direct hardware-level control.

Most battery "health" apps just nag you to unplug your charger. Glide goes deeper: it runs as a privileged background service that talks directly to your Mac's power hardware, managing charging thresholds and thermal load in real time — so your battery ages the way Apple's own engineers would want it to, without you thinking about it.

Under the hood, Glide uses a **root-level LaunchDaemon** communicating over **XPC** to the menu bar app, giving it the same class of hardware access as system-level tools like `smcFanControl`, while keeping the user-facing app itself sandboxed and lightweight. It reads and writes SMC (System Management Controller) keys to intervene on charge limits and heat protection — the two biggest drivers of long-term lithium-ion degradation.

## Why it exists

Apple's built-in "Optimized Battery Charging" is a black box — you can't see it, tune it, or trust it across all workloads. Glide makes that layer transparent and controllable, running invisibly in the background so daily Mac users get years of extra battery life without changing a single habit.

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Swift, AppKit |
| Privileged service | LaunchDaemon (root) |
| IPC | XPC |
| Hardware interface | IOKit, SMC (System Management Controller) |
| Tooling | Xcode |

## Installation

1. Go to the [Releases page](https://github.com/abhiswrld/glide-macos/releases/tag/v1.0.0).
2. Download the latest `Glide.dmg`.
3. Open the `.dmg` and drag **Glide** into your **Applications** folder.
4. Launch Glide.

> **Note:** Since Glide manages hardware-level charging and thermal thresholds, macOS will prompt you to allow it under **System Settings → Privacy & Security**. This is expected, it's what lets Glide talk to your Mac's power hardware directly.
