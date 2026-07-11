import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeSheet: AppSheet?
    @State private var persistenceError: String?
    @StateObject private var accessController = PaidAppAccessController()

    var body: some View {
        Group {
            switch accessController.state {
            case .revoked:
                RevokedAppAccessView(controller: accessController)
            case .unknown, .active:
                appContent
            }
        }
        .task {
            await accessController.refresh()
        }
    }

    private var appContent: some View {
        TodayView(
            onLog: { activeSheet = .log($0, mode: nil) },
            onEdit: { activeSheet = .edit($0) },
            onHistory: { activeSheet = .history },
            onSettings: { activeSheet = .settings }
        )
        .tint(TracalColor.accent)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .log(date, mode):
                LogComposerView(initialDate: date, launchMode: mode) { draft in
                    let entry = MealEntry(confirmedDraft: draft)
                    modelContext.insert(entry)
                    do {
                        try modelContext.save()
                    } catch {
                        modelContext.delete(entry)
                        if let protectedImagePath = draft.protectedImagePath {
                            Task {
                                await ProtectedMealImageStore().remove(path: protectedImagePath)
                            }
                        }
                        persistenceError = error.localizedDescription
                        return
                    }
                    activeSheet = nil
                }
                .presentationDetents([.large])

            case let .edit(entry):
                EntryEditorSheet(entry: entry)
                    .presentationDetents([.large])

            case .history:
                HistoryView()
                    .presentationDetents([.large])

            case .settings:
                SettingsView()
                    .presentationDetents([.large])
            }
        }
        .alert(
            "Meal wasn’t saved",
            isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Please try again.")
        }
        .onOpenURL { url in
            guard let mode = MealLogLaunchMode(url: url) else { return }
            openWidgetAction(mode)
        }
    }

    private func openWidgetAction(_ mode: MealLogLaunchMode) {
        guard activeSheet != nil else {
            activeSheet = .log(.now, mode: mode)
            return
        }

        // Replace any already-presented sheet so a widget tap always applies
        // its requested text, camera, or gallery launch behavior.
        activeSheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            activeSheet = .log(.now, mode: mode)
        }
    }
}

private enum AppSheet: Identifiable {
    case log(Date, mode: MealLogLaunchMode?)
    case edit(MealEntry)
    case history
    case settings

    var id: String {
        switch self {
        case let .log(date, mode):
            "log-\(date.timeIntervalSinceReferenceDate)-\(mode?.rawValue ?? "default")"
        case let .edit(entry): "edit-\(entry.id.uuidString)"
        case .history: "history"
        case .settings: "settings"
        }
    }
}
