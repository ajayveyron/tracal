import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var allEntries: [MealEntry]
    @Query(sort: \DailyGoal.effectiveDate, order: .reverse) private var goals: [DailyGoal]

    @State private var selectedDate = Date.now
    @State private var entryToDelete: MealEntry?

    let onLog: (Date) -> Void
    let onEdit: (MealEntry) -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    private var entries: [MealEntry] {
        allEntries.entries(on: selectedDate)
    }

    private var summary: DailyNutritionSummary {
        DailyNutritionSummary(
            entries: entries,
            goal: goals.effectiveGoal(on: selectedDate)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: TracalSpace.large) {
                    DateStrip(selectedDate: $selectedDate)
                    CalorieSummaryCard(summary: summary, onSetGoal: onSettings)
                    MacroSummaryRow(summary: summary)
                    entriesSection
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(.horizontal, TracalSpace.medium)
                .padding(.top, TracalSpace.medium)
                .padding(.bottom, 104)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(TracalColor.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            Button {
                onLog(selectedDate)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.tracalGlassProminent)
            .padding(.trailing, TracalSpace.large)
            .padding(.bottom, TracalSpace.large)
            .accessibilityLabel("Log food")
            .accessibilityHint("Opens text, camera, and photo options")
            .accessibilityIdentifier("today.log")
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let entryToDelete else { return }
                delete(entryToDelete)
                self.entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TracalSpace.small) {
                    headerTitle
                    headerActions
                }
            } else {
                HStack(alignment: .center) {
                    headerTitle
                    Spacer()
                    headerActions
                }
            }
        }
        .frame(maxWidth: TracalMetric.contentMaxWidth)
        .padding(.horizontal, TracalSpace.medium)
        .padding(.vertical, TracalSpace.small)
        .frame(maxWidth: .infinity)
        .background(TracalColor.backgroundSecondary)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(TracalColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(selectedDate, format: .dateTime.month(.wide).day().year())
                .font(.subheadline)
                .foregroundStyle(TracalColor.textSecondary)
                .accessibilityIdentifier("today.header.date")
        }
    }

    private var headerActions: some View {
        HStack(spacing: TracalSpace.small) {
            Button(action: onHistory) {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: TracalMetric.minimumTapTarget, height: TracalMetric.minimumTapTarget)
            }
            .buttonStyle(.tracalGlass)
            .accessibilityLabel("History")
            .accessibilityIdentifier("today.history")

            Button(action: onSettings) {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: TracalMetric.minimumTapTarget, height: TracalMetric.minimumTapTarget)
            }
            .buttonStyle(.tracalGlass)
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("today.settings")
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: TracalSpace.medium) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: TracalSpace.xSmall) {
                        entriesTitle
                        entryCount
                    }
                } else {
                    HStack {
                        entriesTitle
                        Spacer()
                        entryCount
                    }
                }
            }

            if entries.isEmpty {
                EmptyStateView(
                    title: "Nothing logged",
                    message: "Type what you had or take a photo.",
                    systemImage: "fork.knife"
                )
            } else {
                ForEach(entries) { entry in
                    Button {
                        onEdit(entry)
                    } label: {
                        MealEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            onEdit(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            modelContext.insert(entry.duplicate(at: duplicateDate))
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }

                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityAction(named: "Edit") { onEdit(entry) }
                    .accessibilityAction(named: "Duplicate") {
                        modelContext.insert(entry.duplicate(at: duplicateDate))
                    }
                    .accessibilityAction(named: "Delete") { entryToDelete = entry }
                    .accessibilityHint("Opens meal details")
                }
            }
        }
    }

    private var entriesTitle: some View {
        Text("Logged")
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var entryCount: some View {
        if !entries.isEmpty {
            Text(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(TracalColor.textSecondary)
                .accessibilityIdentifier("today.entry.count")
        }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var duplicateDate: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: .now)
        return calendar.date(
            bySettingHour: components.hour ?? 12,
            minute: components.minute ?? 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private func delete(_ entry: MealEntry) {
        let imagePath = entry.thumbnailRelativePath
        let imageIsShared = imagePath.map { path in
            allEntries.contains { $0.id != entry.id && $0.thumbnailRelativePath == path }
        } ?? false

        modelContext.delete(entry)
        try? modelContext.save()

        if !imageIsShared, let imagePath {
            Task {
                await ProtectedMealImageStore().remove(path: imagePath)
            }
        }
    }
}
