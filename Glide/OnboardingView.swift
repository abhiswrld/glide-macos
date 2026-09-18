import SwiftUI
import ServiceManagement
import GlideCore

struct OnboardingView: View {
    @State private var status: SMAppService.Status = .notRegistered
    @State private var errorMsg: String?
    @State private var isAnimating = false
    @State private var success = false
    @State private var installing = false
    @State private var retryCount = 0
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animated background glow
            RadialGradient(
                colors: [success ? GlideTheme.signalGreen.opacity(0.15) : GlideTheme.teal.opacity(0.15), Color.clear],
                center: .top,
                startRadius: isAnimating ? 50 : 200,
                endRadius: isAnimating ? 400 : 300
            )
            .ignoresSafeArea()
            .opacity(isAnimating ? 1 : 0.6)
            
            VStack(spacing: 24) {
                if success {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GlideTheme.signalGreen, GlideTheme.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: GlideTheme.signalGreen.opacity(0.5), radius: 15, y: 5)
                        .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text("You're all set!")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("Thank you for using Glide. Enjoy seamless battery management.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GlideTheme.signalGreen, GlideTheme.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: GlideTheme.teal.opacity(isAnimating ? 0.6 : 0.2), radius: isAnimating ? 15 : 5, y: isAnimating ? 5 : 0)
                        .offset(y: isAnimating ? -8 : 0)
                        .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text("Welcome to Glide")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("To safely manage your battery's charging limits and protect its long-term health, Glide needs to install a tiny privileged helper tool.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(GlideTheme.orange)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(GlideTheme.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button {
                        installHelper()
                    } label: {
                        HStack(spacing: 8) {
                            if installing {
                                ProgressView()
                                    .controlSize(.small)
                                    .colorScheme(.dark)
                            }
                            Text(installing ? "Installing..." : "Install Helper")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(GlideTheme.blue)
                        .clipShape(Capsule())
                        .shadow(color: GlideTheme.blue.opacity(0.3), radius: 8, y: 4)
                        .scaleEffect(isAnimating ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(installing)
                    
                    VStack(spacing: 8) {
                        Text("You will be prompted for your Mac password.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        VStack(spacing: 4) {
                            Text("If macOS blocked the app, go to System Settings and click 'Open Anyway'.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                            
                            Button("Open Security Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            .font(.caption2)
                            .foregroundStyle(GlideTheme.blue)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(40)
        }
        .frame(width: 450, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            // Don't auto-check SMAppService status on appear.
            // That caused false positives when the daemon was "enabled" but not running.
        }
        .onReceive(timer) { _ in
            // Only poll after user has clicked Install Helper
            if installing && !success {
                retryCount += 1
                if retryCount > 10 {
                    // Give up after ~20 seconds
                    installing = false
                    retryCount = 0
                    errorMsg = "The helper could not start. Make sure you are running Glide from the Applications folder (not from Xcode or Downloads). Rebuild the DMG and reinstall if needed."
                    NSLog("[Glide] Gave up waiting for daemon after 10 retries")
                } else {
                    verifyDaemonAlive()
                }
            }
        }
    }
    
    /// Pings the daemon over XPC to confirm it's actually alive and responding.
    private func verifyDaemonAlive() {
        NSLog("[Glide] Verifying daemon is alive via XPC...")
        
        let conn = NSXPCConnection(machServiceName: GlideXPC.serviceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: GlideDaemonProtocol.self)
        conn.resume()
        
        let proxy = conn.remoteObjectProxyWithErrorHandler { error in
            NSLog("[Glide] XPC ping failed: %@", error.localizedDescription)
        }
        
        guard let daemon = proxy as? GlideDaemonProtocol else {
            NSLog("[Glide] XPC proxy cast failed")
            return
        }
        
        let reply: (Int) -> Void = { limit in
            NSLog("[Glide] XPC ping succeeded! Daemon responded with limit: %d", limit)
            Task { @MainActor in
                conn.invalidate()
                self.installing = false
                self.triggerSuccess()
            }
        }
        daemon.getLimit(withReply: reply)
    }
    
    private func triggerSuccess() {
        if success { return }
        NSLog("[Glide] Triggering success screen")
        withAnimation(.easeIn(duration: 0.5)) {
            success = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete()
        }
    }
    
    private func installHelper() {
        NSLog("[Glide] Install Helper button tapped (osascript mode)")
        
        let bundlePath = Bundle.main.bundlePath
        let daemonSource = "\(bundlePath)/Contents/MacOS/glide-daemon"
        let plistSource = "\(bundlePath)/Contents/Library/LaunchDaemons/com.abhinav.glide-daemon.plist"
        
        // This script will prompt the user for their admin password via standard macOS UI
        let script = """
        do shell script "mkdir -p /Library/PrivilegedHelperTools && cp -f '\(daemonSource)' /Library/PrivilegedHelperTools/glide-daemon && cp -f '\(plistSource)' /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && launchctl load -w /Library/LaunchDaemons/com.abhinav.glide-daemon.plist" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            self.installing = true
            self.errorMsg = nil
            
            // Execute the script synchronously (it blocks until user enters password or cancels)
            DispatchQueue.global(qos: .userInitiated).async {
                appleScript.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if let err = error {
                        NSLog("[Glide] osascript failed: \(err)")
                        self.installing = false
                        let errorNumber = err[NSAppleScript.errorNumber] as? Int
                        if errorNumber == -128 {
                            // User canceled
                            self.errorMsg = "Authentication was canceled."
                        } else {
                            let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                            self.errorMsg = "Failed to install helper: \(msg)"
                        }
                    } else {
                        NSLog("[Glide] osascript succeeded, verifying daemon...")
                        // Daemon should be loaded now, start verification
                        self.verifyDaemonAlive()
                    }
                }
            }
        } else {
            self.errorMsg = "Internal error: Failed to initialize AppleScript."
        }
    }
}
