import SwiftUI
import ServiceManagement
import GlideCore

struct OnboardingView: View {
    @State private var step = 0
    
    // Step 1 State
    @State private var isWelcomeAnimating = false
    
    // Step 2 State
    @State private var errorMsg: String?
    @State private var isHelperAnimating = false
    @State private var installing = false
    @State private var helperSuccess = false
    
    // Step 3 State
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var activationError: String?
    
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animated background glow
            RadialGradient(
                colors: [step == 2 ? GlideTheme.pink.opacity(0.15) : (helperSuccess ? GlideTheme.signalGreen.opacity(0.15) : GlideTheme.teal.opacity(0.15)), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            .opacity(0.8)
            
            VStack {
                if step == 0 {
                    welcomeStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else if step == 1 {
                    installHelperStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else if step == 2 {
                    proActivationStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else if step == 3 {
                    thankYouStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            .animation(.spring(duration: 0.5), value: step)
        }
        .frame(width: 500, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isHelperAnimating = true
            }
        }
    }
    
    // MARK: - Step 0: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.batteryblock.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GlideTheme.signalGreen, GlideTheme.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: GlideTheme.teal.opacity(0.2), radius: 10, y: 0)
                .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text("Welcome to Glide")
                    .font(.system(size: 32, weight: .heavy, design: .default))
                
                Text("A native, zero-overhead macOS battery monitor.\nTake complete physical control of your hardware.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button {
                step = 1
            } label: {
                Text("Get Started")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
                    .background(GlideTheme.blue)
                    .clipShape(Capsule())
                    .shadow(color: GlideTheme.blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 1: Install SMC Helper
    private var installHelperStep: some View {
        VStack(spacing: 24) {
            if helperSuccess {
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
                    Text("SMC Helper Installed")
                        .font(.largeTitle.weight(.bold))
                    
                    Text("Glide now has physical control over your Mac's charging hardware.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                Button {
                    step = 2
                } label: {
                    Text("Continue")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                        .background(GlideTheme.signalGreen)
                        .clipShape(Capsule())
                        .shadow(color: GlideTheme.signalGreen.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            } else {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlideTheme.blue, GlideTheme.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: GlideTheme.purple.opacity(isHelperAnimating ? 0.6 : 0.2), radius: isHelperAnimating ? 15 : 5, y: isHelperAnimating ? 5 : 0)
                    .offset(y: isHelperAnimating ? -8 : 0)
                    .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text("Hardware Permissions")
                        .font(.largeTitle.weight(.bold))
                    
                    Text("To safely manage your battery's charging limits and protect its long-term health, Glide needs to install a tiny privileged helper tool.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                if let err = errorMsg {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GlideTheme.signalRed)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GlideTheme.signalRed.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                Button {
                    installHelper()
                } label: {
                    HStack(spacing: 8) {
                        if installing {
                            ProgressView()
                                .colorScheme(.dark)
                        }
                        Text(installing ? "Installing..." : "Install Helper")
                            .font(.title3.weight(.bold))
                    }
                    .frame(width: 220, height: 52)
                    .foregroundStyle(.white)
                    .background(GlideTheme.blue)
                    .clipShape(Capsule())
                    .shadow(color: GlideTheme.blue.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(installing)
                
                VStack(spacing: 8) {
                    Text("You will be prompted for your Mac password.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    
                    Button("Open Security Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.footnote)
                    .foregroundStyle(GlideTheme.blue)
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
    }
    
    // MARK: - Step 3: Pro Activation
    private var proActivationStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GlideTheme.pink, GlideTheme.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: GlideTheme.pink.opacity(0.5), radius: 15, y: 5)
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text("Activate Glide Pro")
                    .font(.largeTitle.weight(.bold))
                
                Text("Unlock Heat Protection, Sailing Mode, Force Discharge, and Smart Charging routines.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding()
                    .background(Color.black.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(10)
                    .disabled(isActivating)
                    .frame(width: 300)
                

                if let error = activationError {
                    let displayError = error.contains("license_key not found") ? "Invalid license key. Please check your email." : error
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(displayError)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GlideTheme.signalRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GlideTheme.signalRed.opacity(0.15))
                    .clipShape(Capsule())
                    .frame(width: 300, alignment: .center)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Skip for now") {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        step = 3
                    }
                }
                .disabled(isActivating)
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                // Using .cornerRadius(100) instead of Capsule() for macOS background shape
                .cornerRadius(100)
                
                Button(action: activatePro) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Activate Pro")
                            .font(.body.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 180, height: 44)
                .background(GlideTheme.pink)
                .foregroundStyle(.white)
                .cornerRadius(100)
                .shadow(color: GlideTheme.pink.opacity(0.4), radius: 8, y: 4)
                .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }
            .padding(.bottom, 40)
        }
        .padding(20)
        .onChange(of: licenseManager.status) { newStatus in
            if case .licensed = newStatus {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    step = 3
                }
            }
        }
    }
    
    // MARK: - Step 3: Thank You
    private var thankYouStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GlideTheme.signalGreen, GlideTheme.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: GlideTheme.signalGreen.opacity(0.4), radius: 15, y: 5)
                .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.system(size: 32, weight: .heavy, design: .default))
                
                Text("Thank you for choosing Glide!")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Button {
                onComplete()
                // Delay popover open so the onboarding window fully closes first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NotificationCenter.default.post(name: NSNotification.Name("ResetToBatteryTab"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("OpenPopover"), object: nil)
                }
            } label: {
                Text("Continue")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .background(GlideTheme.signalGreen)
            .foregroundStyle(.black)
            .cornerRadius(100)
            .shadow(color: GlideTheme.signalGreen.opacity(0.4), radius: 8, y: 4)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .padding(20)
    }
    
    // MARK: - Logic
    private func activatePro() {
        activationError = nil
        isActivating = true
        Task {
            do {
                try await licenseManager.activateLicense(key: licenseKey)
                // Success — move to thank you step directly
                isActivating = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    step = 3
                }
            } catch {
                activationError = error.localizedDescription
                isActivating = false
            }
        }
    }
    
    private func verifyDaemonAlive(retryCount: Int = 0) {
        let conn = NSXPCConnection(machServiceName: GlideXPC.serviceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: GlideDaemonProtocol.self)
        conn.resume()
        
        let proxy = conn.remoteObjectProxyWithErrorHandler { err in
            DispatchQueue.main.async {
                if retryCount < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.verifyDaemonAlive(retryCount: retryCount + 1)
                    }
                } else {
                    self.installing = false
                    self.errorMsg = "The helper could not be reached. Error: \(err.localizedDescription)"
                }
            }
        }
        
        guard let daemon = proxy as? GlideDaemonProtocol else { return }
        
        let reply: (Int) -> Void = { _ in
            DispatchQueue.main.async {
                conn.invalidate()
                self.installing = false
                withAnimation(.easeIn(duration: 0.5)) {
                    self.helperSuccess = true
                }
            }
        }
        daemon.getLimit(withReply: reply)
    }
    
    private func installHelper() {
        let bundlePath = Bundle.main.bundlePath
        let daemonSource = "\(bundlePath)/Contents/MacOS/glide-daemon"
        let plistSource = "\(bundlePath)/Contents/Library/LaunchDaemons/com.abhinav.glide-daemon.plist"
        
        let script = """
        do shell script "launchctl unload -w /Library/LaunchDaemons/com.abhinav.glide-daemon.plist 2>/dev/null || true; rm -f /Library/PrivilegedHelperTools/glide-daemon 2>/dev/null || true; mkdir -p /Library/PrivilegedHelperTools && cp -f '\(daemonSource)' /Library/PrivilegedHelperTools/glide-daemon && chown root:wheel /Library/PrivilegedHelperTools/glide-daemon && chmod 755 /Library/PrivilegedHelperTools/glide-daemon && cp -f '\(plistSource)' /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && chown root:wheel /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && chmod 644 /Library/LaunchDaemons/com.abhinav.glide-daemon.plist && launchctl load -w /Library/LaunchDaemons/com.abhinav.glide-daemon.plist" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            self.installing = true
            self.errorMsg = nil
            
            DispatchQueue.global(qos: .userInitiated).async {
                appleScript.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    // Only bring the onboarding window back to front — never touch other windows
                    // (the old fallback activated ALL windows including the popover)
                    if let onboardingWindow = NSApp.windows.first(where: {
                        $0.contentView is NSHostingView<OnboardingView>
                    }) {
                        onboardingWindow.makeKeyAndOrderFront(nil)
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    
                    if let err = error {
                        self.installing = false
                        let errorNumber = err[NSAppleScript.errorNumber] as? Int
                        if errorNumber == -128 {
                            self.errorMsg = "Authentication was canceled."
                        } else {
                            let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                            self.errorMsg = "Failed to install helper: \(msg)"
                        }
                    } else {
                        self.verifyDaemonAlive()
                    }
                }
            }
        } else {
            self.errorMsg = "Internal error."
        }
    }
}
