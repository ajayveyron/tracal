import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeSheet: AppSheet?
    @State private var persistenceError: String?

    var body: some View {
        TodayView(
            onLog: { activeSheet = .log($0) },
            onEdit: { activeSheet = .edit($0) },
            onHistory: { activeSheet = .history },
            onSettings: { activeSheet = .settings }
        )
        .tint(TracalColor.accent)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .log(date):
                LogComposerView(initialDate: date) { draft in
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
    }
}

private enum AppSheet: Identifiable {
    case log(Date)
    case edit(MealEntry)
    case history
    case settings

    var id: String {
        switch self {
        case let .log(date): "log-\(date.timeIntervalSinceReferenceDate)"
        case let .edit(entry): "edit-\(entry.id.uuidString)"
        case .history: "history"
        case .settings: "settings"
        }
    }
}
