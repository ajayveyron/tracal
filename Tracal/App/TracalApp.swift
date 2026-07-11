import SwiftData
import SwiftUI
import UIKit

@main
struct TracalApp: App {
    init() {
        UIScrollView.appearance().bounces = false
    }

    private let modelContainer: ModelContainer = {
        ProviderCredentialStore().prepareFreshInstallation()

        let schema = Schema([
            DailyGoal.self,
            MealEntry.self,
            FoodItem.self,
            PendingAnalysis.self,
            AIUsageRecord.self,
        ])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create the local Tracal store: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Biometric app lock remains compiled out while direct camera
            // capture is reintroduced through UIKit's system picker only.
            appRoot
                .preferredColorScheme(nil)
        }
        .modelContainer(modelContainer)
    }

    @ViewBuilder
    private var appRoot: some View {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-accessibility") {
            AppRootView()
                .environment(\.dynamicTypeSize, .accessibility5)
                .environment(\.accessibilityReduceMotion, true)
        } else {
            AppRootView()
        }
    }
}
