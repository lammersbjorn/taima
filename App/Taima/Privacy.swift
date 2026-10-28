import LocalAuthentication
import SwiftUI
import TaimaCore

/// The lock and the app switcher cover, drawn in their own window above
/// every sheet and cover, so nothing in the app shows through.
@Observable
final class PrivacyGate {
    var locked = UserDefaults.standard.bool(forKey: "privacy.lock")
    var covered = false
    var authenticating = false
    var discreet = UserDefaults.standard.bool(forKey: "privacy.discreet")
    @ObservationIgnored private var window: UIWindow?

    var showsShield: Bool { locked || covered }

    /// Shows or hides the shield window to match the state.
    func update() {
        if showsShield {
            guard window == nil, let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: ShieldView(gate: self))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            window.isHidden = false
            self.window = window
        } else if let window {
            window.isHidden = true
            self.window = nil
        }
    }

    func unlock() {
        guard !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        // Falls back to the passcode, so a failed Face ID never locks you out.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            locked = false
            update()
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Unlock Taima")) { success, _ in
            Task { @MainActor in
                self.authenticating = false
                if success {
                    self.locked = false
                    self.update()
                }
            }
        }
    }

    /// Whether the device has a passcode, without which the lock can't work.
    static var deviceCanLock: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

private struct ShieldView: View {
    let gate: PrivacyGate

    var body: some View {
        Group {
            if gate.locked {
                LockScreen(discreet: gate.discreet, authenticating: gate.authenticating, unlock: gate.unlock)
            } else {
                CoverScreen(discreet: gate.discreet)
            }
        }
        .transition(.opacity)
    }
}

/// Drives the gate from the scene phase and settings, and tells the model
/// when the app is locked so links wait.
struct PrivacyShield: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppModel.self) private var model
    @AppStorage("privacy.lock") private var lockEnabled = false
    @AppStorage("privacy.discreet") private var discreet = false
    @State private var gate = PrivacyGate()
    /// Auto-prompt once per return from the background; a cancelled prompt
    /// makes the app inactive and active again, which must not re-prompt.
    @State private var promptOnActive = true

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                gate.discreet = discreet
                if phase == .background, lockEnabled {
                    gate.locked = true
                    promptOnActive = true
                }
                gate.locked = gate.locked && lockEnabled
                gate.covered = phase != .active && (lockEnabled || discreet)
                gate.update()
                if phase == .active, gate.locked, promptOnActive {
                    promptOnActive = false
                    gate.unlock()
                }
            }
            .onChange(of: gate.locked, initial: true) { _, locked in model.isLocked = locked }
            .onChange(of: lockEnabled) { _, on in
                if !on { gate.locked = false; gate.update() }
            }
            .onChange(of: discreet) { _, on in gate.discreet = on }
    }
}

private struct LockScreen: View {
    let discreet: Bool
    let authenticating: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 18) {
                if discreet {
                    Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(.secondary)
                } else {
                    Mascot(size: 110)
                }
                Text("Taima is locked").font(.title2.bold())
                Button(authenticating ? String(localized: "Unlocking…") : String(localized: "Unlock"), systemImage: "faceid", action: unlock)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(authenticating)
            }
        }
    }
}

private struct CoverScreen: View {
    let discreet: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            if discreet {
                Image(systemName: "doc.text").font(.system(size: 54)).foregroundStyle(.secondary)
            } else {
                Mascot(size: 100, animated: false)
            }
        }
    }
}

/// Switches the icon and what shared surfaces may show.
enum DiscreetMode {
    static func apply(_ on: Bool) {
        SharedContainer.isDiscreet = on
        let name = on ? "AppIcon-Discreet" : nil
        if UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name {
            UIApplication.shared.setAlternateIconName(name)
        }
    }
}
