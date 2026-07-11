#if TRACAL_ENABLE_APP_LOCK
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var message: String?

    private var context: LAContext?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            isUnlocked = true
        }
    }

    func lock() {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        context?.invalidate()
        context = nil
        isAuthenticating = false
        isUnlocked = false
        message = nil
    }

    func unlockIfNeeded() async {
        guard !isUnlocked, !isAuthenticating else { return }

        #if targetEnvironment(simulator)
        isUnlocked = true
        return
        #else
        let context = LAContext()
        context.localizedCancelTitle = "Keep locked"
        context.localizedFallbackTitle = "Use Passcode"

        var authorizationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authorizationError) else {
            message = "Turn on Face ID or a device passcode to unlock Tracal."
            return
        }

        self.context = context
        isAuthenticating = true
        message = nil

        do {
            let authenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your private meal history"
            )
            guard self.context === context else { return }
            isUnlocked = authenticated
            if !authenticated {
                message = "Tracal stayed locked."
            }
        } catch {
            guard self.context === context else { return }
            message = "Tracal stayed locked."
        }

        if self.context === context {
            // Authentication is complete. Do not retain a live biometric
            // context while the app later opens an AVCapture camera client.
            // Explicit invalidation also makes the TrueDepth resource lifetime
            // deterministic on physical devices and beta OS releases.
            context.invalidate()
            self.context = nil
            isAuthenticating = false
        }
        #endif
    }
}

struct AppLockGate<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = AppLockController()

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            if controller.isUnlocked {
                content
            } else {
                AppLockedView(
                    isAuthenticating: controller.isAuthenticating,
                    message: controller.message,
                    onUnlock: {
                        Task { await controller.unlockIfNeeded() }
                    }
                )
            }
        }
        .task {
            await controller.unlockIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                controller.lock()
            case .active:
                Task { await controller.unlockIfNeeded() }
            case .inactive:
                break
            @unknown default:
                controller.lock()
            }
        }
    }
}

private struct AppLockedView: View {
    let isAuthenticating: Bool
    let message: String?
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: TracalSpace.large) {
            Image(systemName: "faceid")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(TracalColor.accent)
                .accessibilityHidden(true)

            VStack(spacing: TracalSpace.small) {
                Text("Tracal is locked")
                    .font(.title.bold())
                    .foregroundStyle(TracalColor.textPrimary)
                Text(message ?? "Use Face ID or your device passcode.")
                    .font(.subheadline)
                    .foregroundStyle(TracalColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onUnlock) {
                Group {
                    if isAuthenticating {
                        ProgressView()
                    } else {
                        Text("Unlock Tracal")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.tracalGlassProminent)
            .disabled(isAuthenticating)
        }
        .padding(TracalSpace.xLarge)
        .frame(maxWidth: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: TracalRadius.large, style: .continuous))
        .padding(TracalSpace.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TracalColor.backgroundPrimary.ignoresSafeArea())
    }
}
#endif
