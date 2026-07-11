import SwiftData
import SwiftUI
import UIKit

struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @ScaledMetric(relativeTo: .largeTitle) private var calorieFontSize: CGFloat = 44
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var allEntries: [MealEntry]
    @Bindable var entry: MealEntry
    @State private var showingDeleteConfirmation = false
    @FocusState private var focusedField: EntryEditorField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.large) {
                    TextField("Meal name", text: $entry.title, axis: .vertical)
                        .font(.title2.bold())
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityIdentifier("entry.title")
                        .padding(TracalSpace.medium)
                        .tonalSurface()

                    DatePicker("Logged", selection: $entry.loggedAt)
                        .padding(TracalSpace.medium)
                        .tonalSurface()

                    nutritionSummary

                    if hasOriginalInput {
                        originalInput
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete log", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.tracalGlassDestructive)
                    .accessibilityIdentifier("entry.delete")
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(TracalSpace.medium)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: save) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
                    .buttonStyle(.tracalGlassProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("entry.save")
                    .padding(.horizontal, TracalSpace.medium)
                    .padding(.vertical, TracalSpace.small)
                    .background(TracalColor.backgroundPrimary)
            }
            .navigationTitle("Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        modelContext.rollback()
                        dismiss()
                    }
                    .tint(TracalColor.accent)
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
            }
            .confirmationDialog(
                "Delete this log?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete log", role: .destructive, action: deleteEntry)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private var hasOriginalInput: Bool {
        !(entry.originalDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || originalImage != nil
    }

    private var originalInput: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            Text("Original input")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if let description = entry.originalDescription,
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(TracalSpace.medium)
                    .tonalSurface()
                    .accessibilityIdentifier("entry.original.description")
            }

            if let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: TracalRadius.medium, style: .continuous))
                    .accessibilityLabel("Original meal image")
                    .accessibilityIdentifier("entry.original.image")
            }
        }
    }

    private var nutritionSummary: some View {
        VStack(alignment: .leading, spacing: TracalSpace.large) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.caloriesKcal, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(TracalColor.textSecondary)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: TracalSpace.small) {
                        storedMacros
                    }
                } else {
                    HStack(spacing: TracalSpace.small) {
                        storedMacros
                    }
                }
            }
        }
        .padding(TracalSpace.large)
        .tonalSurface()
        .accessibilityIdentifier("entry.nutrition.summary")
    }

    private var originalImage: UIImage? {
        guard let relativePath = entry.thumbnailRelativePath else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = documents?.appending(path: relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func save() {
        entry.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func deleteEntry() {
        let imagePath = entry.thumbnailRelativePath
        let imageIsShared = imagePath.map { path in
            allEntries.contains { $0.id != entry.id && $0.thumbnailRelativePath == path }
        } ?? false

        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()

        if !imageIsShared, let imagePath {
            Task {
                await ProtectedMealImageStore().remove(path: imagePath)
            }
        }
    }
}

private enum EntryEditorField: Hashable {
    case title
}

private extension EntryEditorSheet {
    @ViewBuilder
    var storedMacros: some View {
        StoredMacro(title: "Protein", value: entry.proteinG, color: TracalColor.protein)
        StoredMacro(title: "Carbs", value: entry.carbohydrateG, color: TracalColor.carbohydrate)
        StoredMacro(title: "Fat", value: entry.fatG, color: TracalColor.fat)
    }
}

private struct StoredMacro: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value, format: .number.precision(.fractionLength(0...1)))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(0...1)))) grams")
    }
}
