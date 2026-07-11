import StoreKit
import SwiftUI

enum AppAccessState: Hashable, Sendable {
    case unknown
    case active
    case revoked(Date?)
}

@MainActor
final class PaidAppAccessController: ObservableObject {
    @Published private(set) var state: AppAccessState = .unknown

    private static let cachedRevocationKey = "paidAppPurchaseRevoked"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func refresh() async {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                if let revokedAt = Self.revocationDate(from: transaction.jsonRepresentation) {
                    defaults.set(true, forKey: Self.cachedRevocationKey)
                    state = .revoked(revokedAt)
                } else {
                    defaults.removeObject(forKey: Self.cachedRevocationKey)
                    state = .active
                }
            case .unverified:
                useCachedState()
            }
        } catch {
            // A paid app has already passed App Store acquisition. Never lock
            // a legitimate customer only because StoreKit is temporarily
            // offline or unavailable in a development/TestFlight environment.
            useCachedState()
        }
    }

    func clearLocalState() {
        defaults.removeObject(forKey: Self.cachedRevocationKey)
        state = .active
    }

    private func useCachedState() {
        state = defaults.bool(forKey: Self.cachedRevocationKey) ? .revoked(nil) : .active
    }

    /// Xcode 27 exposes `AppTransaction.revocationDate` directly. Tracal's
    /// release toolchain is Xcode 26.6, so read the same field from StoreKit's
    /// already-verified JSON payload until that SDK property is available.
    private static func revocationDate(from payload: Data) -> Date? {
        guard
            let object = try? JSONSerialization.jsonObject(with: payload),
            let dictionary = object as? [String: Any],
            let rawValue = dictionary["revocationDate"]
        else {
            return nil
        }

        let milliseconds: Double?
        switch rawValue {
        case let number as NSNumber:
            milliseconds = number.doubleValue
        case let string as String:
            milliseconds = Double(string)
        default:
            milliseconds = nil
        }

        guard let milliseconds, milliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }
}

struct RevokedAppAccessView: View {
    @ObservedObject var controller: PaidAppAccessController
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: TracalSpace.large) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44))
                .foregroundStyle(TracalColor.accent)
                .accessibilityHidden(true)

            VStack(spacing: TracalSpace.small) {
                Text("Purchase no longer active")
                    .font(.title2.bold())
                Text("Apple has refunded or revoked this app purchase. Repurchase Tracal in the App Store, then refresh access.")
                    .foregroundStyle(TracalColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh access") {
                Task { await controller.refresh() }
            }
            .buttonStyle(.tracalGlassProminent)

            Button("Apple purchase support") {
                openURL(URL(string: "https://reportaproblem.apple.com")!)
            }
            .buttonStyle(.tracalGlass)
        }
        .padding(TracalSpace.xLarge)
        .frame(maxWidth: TracalMetric.contentMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TracalColor.backgroundPrimary.ignoresSafeArea())
    }
}
