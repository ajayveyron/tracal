import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var allEntries: [MealEntry]
    @Query(sort: \DailyGoal.effectiveDate, order: .reverse) private var goals: [DailyGoal]

    @State private var displayedMonth = Date.now
    @State private var entryToDelete: MealEntry?
    @State private var entryToEdit: MealEntry?

    private var monthEntries: [MealEntry] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        return allEntries.filter { interval.contains($0.loggedAt) }
    }

    private var dayGroups: [HistoryDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: monthEntries) {
            calendar.startOfDay(for: $0.loggedAt)
        }
        return groups
            .map { HistoryDayGroup(date: $0.key, entries: $0.value.sorted { $0.loggedAt > $1.loggedAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TracalSpace.large) {
                    monthPicker

                    if dayGroups.isEmpty {
                        EmptyStateView(
                            title: "No entries this month",
                            message: "Saved meals will appear here.",
                            systemImage: "calendar"
                        )
                    } else {
                        ForEach(dayGroups) { group in
                            daySection(group)
                        }
                    }
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(.horizontal, TracalSpace.medium)
                .padding(.top, TracalSpace.medium)
                .padding(.bottom, TracalSpace.section)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(TracalColor.accent)
                }
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
            .sheet(item: $entryToEdit) { entry in
                EntryEditorSheet(entry: entry)
                    .presentationDetents([.large])
            }
        }
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

    private var monthPicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TracalSpace.small) {
                    monthTitle
                    monthButtons
                }
            } else {
                HStack {
                    previousMonthButton
                    Spacer()
                    monthTitle
                    Spacer()
                    nextMonthButton
                }
            }
        }
        .padding(.horizontal, TracalSpace.small)
        .padding(.vertical, TracalSpace.xSmall)
        .tonalSurface(.tertiary)
    }

    private var monthButtons: some View {
        HStack(spacing: TracalSpace.xLarge) {
            previousMonthButton
            nextMonthButton
        }
    }

    private var previousMonthButton: some View {
        Button {
            moveMonth(by: -1)
        } label: {
            Image(systemName: "chevron.left")
                .frame(width: TracalMetric.minimumTapTarget, height: TracalMetric.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .tint(TracalColor.accent)
        .accessibilityLabel("Previous month")
    }

    private var nextMonthButton: some View {
        Button {
            moveMonth(by: 1)
        } label: {
            Image(systemName: "chevron.right")
                .frame(width: TracalMetric.minimumTapTarget, height: TracalMetric.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .tint(TracalColor.accent)
        .disabled(isCurrentMonth)
        .opacity(isCurrentMonth ? 0.35 : 1)
        .accessibilityLabel("Next month")
    }

    private var monthTitle: some View {
        Text(displayedMonth, format: .dateTime.month(.wide).year())
            .font(.headline)
            .foregroundStyle(TracalColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func daySection(_ group: HistoryDayGroup) -> some View {
        let summary = DailyNutritionSummary(
            entries: group.entries,
            goal: goals.effectiveGoal(on: group.date)
        )

        return VStack(alignment: .leading, spacing: TracalSpace.small) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: TracalSpace.xSmall) {
                        dayHeading(group)
                        calorieHeading(summary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        dayHeading(group)
                        Spacer()
                        calorieHeading(summary)
                    }
                }
            }
            .padding(.horizontal, TracalSpace.xSmall)

            ForEach(group.entries) { entry in
                Button {
                    entryToEdit = entry
                } label: {
                    MealEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        entryToEdit = entry
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        modelContext.insert(entry.duplicate())
                    } label: {
                        Label("Duplicate today", systemImage: "plus.square.on.square")
                    }

                    Button(role: .destructive) {
                        entryToDelete = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .accessibilityHint("Opens meal details")
                .accessibilityAction(named: "Duplicate today") {
                    modelContext.insert(entry.duplicate())
                }
                .accessibilityAction(named: "Delete") { entryToDelete = entry }
            }
        }
    }

    private func dayHeading(_ group: HistoryDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.date, format: .dateTime.weekday(.wide))
                .font(.headline)
            Text(group.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func calorieHeading(_ summary: DailyNutritionSummary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(summary.consumed.caloriesKcal, format: .number.precision(.fractionLength(0)))
                .font(.headline.monospacedDigit())
            Text("kcal")
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private func moveMonth(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            displayedMonth = newDate
        }
    }
}

private struct HistoryDayGroup: Identifiable {
    let date: Date
    let entries: [MealEntry]

    var id: Date { date }
}
