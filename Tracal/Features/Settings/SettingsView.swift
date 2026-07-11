import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \DailyGoal.effectiveDate, order: .reverse) private var goals: [DailyGoal]
    @Query(sort: \AIUsageRecord.createdAt, order: .reverse) private var usageRecords: [AIUsageRecord]
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var meals: [MealEntry]

    @AppStorage(AIProviderPreferences.activeProviderKey)
    private var activeProviderRawValue = AIProvider.gemini.rawValue

    @State private var showingGoalEditor = false
    @State private var selectedProvider: AIProvider?
    @State private var showingUsage = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionError: String?
    @State private var connectedProviders: Set<AIProvider> = []
    @State private var backupDocument: TracalBackupDocument?
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var backupError: String?

    private var activeProvider: AIProvider {
        AIProvider(rawValue: activeProviderRawValue) ?? .gemini
    }

    private var currentGoal: DailyGoal? {
        goals.effectiveGoal(on: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.xLarge) {
                    Text("Settings")
                        .font(.largeTitle.bold())

                    SettingsSection(title: "Goals") {
                        Button {
                            showingGoalEditor = true
                        } label: {
                            SettingsRow(
                                title: "Daily target",
                                value: goalSummary,
                                systemImage: "target",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.goal")
                    }

                    SettingsSection(title: "Analysis") {
                        ForEach(AIProvider.allCases) { provider in
                            Button {
                                selectedProvider = provider
                            } label: {
                                SettingsRow(
                                    title: provider.displayName,
                                    value: providerStatus(provider),
                                    systemImage: provider.systemImage,
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.provider.\(provider.rawValue)")
                        }

                        SettingsRow(
                            title: "Offline fallback",
                            value: "Apple Intelligence for text when available",
                            systemImage: "iphone.gen3"
                        )
                    }

                    SettingsSection(title: "AI usage") {
                        Button {
                            showingUsage = true
                        } label: {
                            SettingsRow(
                                title: "Estimated API cost",
                                value: usageSummary,
                                systemImage: "chart.bar",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.usage")
                    }

                    SettingsSection(title: "Security") {
                        SettingsRow(
                            title: "App lock",
                            value: "Off while camera compatibility is validated",
                            systemImage: "lock.open"
                        )
                    }

                    SettingsSection(title: "Data") {
                        Button(action: exportBackup) {
                            SettingsRow(
                                title: "Export backup",
                                value: "Meals, goals, photos, and usage history · API keys excluded",
                                systemImage: "square.and.arrow.up",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingBackupImporter = true
                        } label: {
                            SettingsRow(
                                title: "Import backup",
                                value: "Adds records that are not already on this iPhone",
                                systemImage: "square.and.arrow.down",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            SettingsRow(
                                title: "Delete all Tracal data",
                                value: "Meals, goals, photos, usage history, and API keys",
                                systemImage: "trash",
                                isDestructive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Help") {
                        Button {
                            openURL(URL(string: "https://reportaproblem.apple.com")!)
                        } label: {
                            SettingsRow(
                                title: "Request an Apple refund",
                                value: "Purchases and refunds are handled by Apple",
                                systemImage: "apple.logo",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Saved meals stay on this iPhone. Cloud analysis sends only the current meal text or sanitized photo to the provider you select.")
                        .font(.footnote)
                        .foregroundStyle(TracalColor.textSecondary)
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(.horizontal, TracalSpace.medium)
                .padding(.top, TracalSpace.small)
                .padding(.bottom, TracalSpace.section)
                .frame(maxWidth: .infinity)
            }
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(TracalColor.accent)
                        .accessibilityIdentifier("settings.done")
                }
            }
            .sheet(isPresented: $showingGoalEditor) {
                GoalEditorSheet(existingGoal: currentGoal)
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedProvider, onDismiss: refreshProviderStatus) { provider in
                ProviderSetupSheet(
                    provider: provider,
                    container: modelContext.container,
                    onChanged: refreshProviderStatus
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingUsage) {
                AIUsageDetailView(
                    records: usageRecords,
                    cloudMealCount: meals.filter { $0.analysisRoute.isCloudProvider }.count,
                    onDeviceMealCount: meals.filter { !$0.analysisRoute.isCloudProvider }.count
                )
                    .presentationDetents([.large])
            }
            .confirmationDialog(
                "Delete all Tracal data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete all data", role: .destructive, action: deleteAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes local meals, goals, photos, usage history, and API keys. It cannot be undone.")
            }
            .alert(
                "Couldn’t delete data",
                isPresented: Binding(
                    get: { deletionError != nil },
                    set: { if !$0 { deletionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "Please try again.")
            }
            .alert(
                "Backup failed",
                isPresented: Binding(
                    get: { backupError != nil },
                    set: { if !$0 { backupError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { backupError = nil }
            } message: {
                Text(backupError ?? "Please try again.")
            }
            .fileExporter(
                isPresented: $showingBackupExporter,
                document: backupDocument,
                contentType: .tracalBackup,
                defaultFilename: "Tracal-Backup"
            ) { result in
                if case .failure(let error) = result {
                    backupError = error.localizedDescription
                }
                backupDocument = nil
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.tracalBackup, .json],
                allowsMultipleSelection: false
            ) { result in
                importBackup(result)
            }
            .task {
                refreshProviderStatus()
            }
        }
    }

    private var goalSummary: String {
        guard let currentGoal else { return "Not set" }
        return "\(currentGoal.calorieTarget.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    private var usageSummary: String {
        usageLine(usageRecords)
    }

    private func providerStatus(_ provider: AIProvider) -> String {
        let state = connectedProviders.contains(provider) ? "Connected" : "API key needed"
        return provider == activeProvider ? "\(state) · Selected" : state
    }

    private func refreshProviderStatus() {
        let store = ProviderCredentialStore()
        connectedProviders = Set(AIProvider.allCases.filter(store.contains))
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: AIUsageRecord.self)
            try modelContext.delete(model: PendingAnalysis.self)
            try modelContext.delete(model: MealEntry.self)
            try modelContext.delete(model: DailyGoal.self)
            try modelContext.save()
            try ProviderCredentialStore().deleteAll()
            AIProviderPreferences().reset()
            connectedProviders = []
            Task { await ProtectedMealImageStore().removeAll() }
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private func exportBackup() {
        Task {
            do {
                backupDocument = try await TracalBackupService(context: modelContext).exportDocument()
                showingBackupExporter = true
            } catch {
                backupError = error.localizedDescription
            }
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        Task {
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                try await TracalBackupService(context: modelContext).importDocument(data)
            } catch {
                backupError = error.localizedDescription
            }
        }
    }
}

private struct ProviderSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let provider: AIProvider
    let container: ModelContainer
    let onChanged: () -> Void

    @State private var model = ""
    @State private var credential = ""
    @State private var consent = false
    @State private var credentialStored = false
    @State private var isTesting = false
    @State private var statusMessage: String?
    @State private var isError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.large) {
                    VStack(alignment: .leading, spacing: TracalSpace.small) {
                        Text(provider.displayName)
                            .font(.largeTitle.bold())
                        Text("Use a dedicated API key with a provider spending limit. The key stays in this iPhone's Keychain and is sent only to \(provider.displayName).")
                            .font(.subheadline)
                            .foregroundStyle(TracalColor.textSecondary)
                    }

                    VStack(spacing: TracalSpace.small) {
                        SecureField(
                            credentialStored ? "Leave blank to keep saved key" : "API key",
                            text: $credential
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("provider.key")
                        .padding(TracalSpace.medium)
                        .tonalSurface()

                        TextField("Model", text: $model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("provider.model")
                            .padding(TracalSpace.medium)
                            .tonalSurface()
                    }

                    Toggle(isOn: $consent) {
                        Text("Allow the current meal description and sanitized photo to leave this iPhone for \(provider.displayName) analysis.")
                            .font(.subheadline)
                    }
                    .tint(TracalColor.accent)
                    .accessibilityIdentifier("provider.consent")

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(isError ? TracalColor.destructive : TracalColor.textSecondary)
                    }

                    Button(action: saveAndTest) {
                        HStack {
                            if isTesting { ProgressView().controlSize(.small) }
                            Text(isTesting ? "Testing…" : "Save and test")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.tracalGlassProminent)
                    .disabled(isTesting || (!credentialStored && credential.isEmpty) || !consent)
                    .accessibilityIdentifier("provider.save")

                    HStack {
                        Button("Create key") { openURL(provider.apiKeyURL) }
                            .buttonStyle(.tracalGlass)
                        Button("Billing") { openURL(provider.billingURL) }
                            .buttonStyle(.tracalGlass)
                    }

                    if credentialStored {
                        Button(role: .destructive, action: deleteKey) {
                            Text("Delete \(provider.displayName) key")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.tracalGlassDestructive)
                    }
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(TracalSpace.large)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(TracalColor.accent)
                }
            }
            .onAppear {
                let preferences = AIProviderPreferences()
                model = preferences.model(for: provider)
                consent = preferences.hasConsent(for: provider)
                credentialStored = ProviderCredentialStore().contains(provider)
            }
        }
    }

    private func saveAndTest() {
        let store = ProviderCredentialStore()
        let preferences = AIProviderPreferences()
        do {
            if !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try store.store(credential, for: provider)
            }
            preferences.setModel(model, for: provider)
            preferences.setConsent(consent, for: provider)
            preferences.activeProvider = provider
            credential = ""
            credentialStored = true
            onChanged()
        } catch {
            isError = true
            statusMessage = "The API key could not be saved."
            return
        }

        isTesting = true
        isError = false
        statusMessage = "Test requests may incur a very small provider charge."
        Task {
            do {
                let recorder = SwiftDataAIUsageRecorder(container: container)
                let service = DirectProviderService(usageRecorder: recorder)
                try await service.testConnection(provider: provider)
                await MainActor.run {
                    statusMessage = "Connected. \(provider.displayName) returned a valid structured meal."
                    isError = false
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? "The provider connection failed."
                    isError = true
                    isTesting = false
                }
            }
        }
    }

    private func deleteKey() {
        do {
            try ProviderCredentialStore().delete(provider)
            AIProviderPreferences().setConsent(false, for: provider)
            credentialStored = false
            consent = false
            statusMessage = "API key removed from this iPhone."
            isError = false
            onChanged()
        } catch {
            statusMessage = "The API key could not be removed."
            isError = true
        }
    }
}

private struct AIUsageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let records: [AIUsageRecord]
    let cloudMealCount: Int
    let onDeviceMealCount: Int
    @State private var showingReset = false

    private var monthRecords: [AIUsageRecord] {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .distantPast
        return records.filter { $0.createdAt >= start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.xLarge) {
                    Text("AI usage")
                        .font(.largeTitle.bold())

                    UsageSummaryCard(title: "This month", records: monthRecords)
                    UsageSummaryCard(title: "All time on this iPhone", records: records)

                    SettingsSection(title: "Analysis route") {
                        SettingsRow(
                            title: "Cloud meals",
                            value: "\(cloudMealCount.formatted()) saved analyses",
                            systemImage: "cloud"
                        )
                        SettingsRow(
                            title: "On-device meals",
                            value: "\(onDeviceMealCount.formatted()) saved analyses",
                            systemImage: "iphone.gen3"
                        )
                    }

                    SettingsSection(title: "By provider") {
                        ForEach(AIProvider.allCases) { provider in
                            let values = records.filter { $0.provider == provider }
                            SettingsRow(
                                title: provider.displayName,
                                value: usageLine(values),
                                systemImage: provider.systemImage
                            )
                        }
                    }

                    if !modelBreakdown.isEmpty {
                        SettingsSection(title: "By model") {
                            ForEach(modelBreakdown, id: \.key) { group in
                                SettingsRow(
                                    title: group.model,
                                    value: "\(group.provider.displayName) · \(usageLine(group.records))",
                                    systemImage: group.provider.systemImage
                                )
                            }
                        }
                    }

                    if !records.isEmpty {
                        SettingsSection(title: "Recent requests") {
                            ForEach(Array(records.prefix(20))) { record in
                                SettingsRow(
                                    title: record.model,
                                    value: "\(record.createdAt.formatted(date: .abbreviated, time: .shortened)) · attempt \(record.attemptNumber) · \(record.result.rawValue) · \(usageLine([record]))",
                                    systemImage: record.result == .success ? "checkmark.circle" : "exclamationmark.circle"
                                )
                            }
                        }
                    }

                    Text(pricingNote)
                        .font(.footnote)
                        .foregroundStyle(TracalColor.textSecondary)

                    Button(role: .destructive) {
                        showingReset = true
                    } label: {
                        Text("Reset usage history")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.tracalGlassDestructive)
                    .disabled(records.isEmpty)
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(TracalSpace.large)
                .frame(maxWidth: .infinity)
            }
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(TracalColor.accent)
                }
            }
            .confirmationDialog("Reset AI usage history?", isPresented: $showingReset) {
                Button("Reset", role: .destructive) {
                    try? modelContext.delete(model: AIUsageRecord.self)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Meal logs and provider keys are not affected.")
            }
        }
    }

    private var modelBreakdown: [(key: String, provider: AIProvider, model: String, records: [AIUsageRecord])] {
        Dictionary(grouping: records) { "\($0.providerRawValue)|\($0.model)" }
            .compactMap { key, values in
                guard let provider = values.first?.provider, let model = values.first?.model else {
                    return nil
                }
                return (key, provider, model, values)
            }
            .sorted { $0.key < $1.key }
    }

    private var pricingNote: String {
        let date = ModelPricingCatalog.current.latestEffectiveDate?
            .formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
        return "Estimates use public list prices from catalog \(ModelPricingCatalog.current.version), effective \(date). Free tiers, discounts, taxes, and provider billing rules can differ. Provider dashboards are the billing source of truth."
    }
}

private struct UsageSummaryCard: View {
    let title: String
    let records: [AIUsageRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            Text(title)
                .font(.headline)
            Text(estimatedCost)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Estimated API cost · \(tokenText(records))")
                .font(.subheadline)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .padding(TracalSpace.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tonalSurface()
    }

    private var estimatedCost: String {
        estimatedCostText(records)
    }
}

private func usageLine(_ records: [AIUsageRecord]) -> String {
    guard !records.isEmpty else { return "No cloud requests" }
    return "Estimated \(estimatedCostText(records)) · \(tokenText(records))"
}

private func estimatedCostText(_ records: [AIUsageRecord]) -> String {
    let known = records.compactMap(\.estimatedCostMicrodollars)
    guard !known.isEmpty else { return "cost unknown" }
    let formatted = (Decimal(known.reduce(Int64(0), +)) / 1_000_000).formatted(
        .currency(code: "USD").precision(.fractionLength(2...4))
    )
    return known.count == records.count ? formatted : "\(formatted) + unknown"
}

private func tokenText(_ records: [AIUsageRecord]) -> String {
    let known = records.compactMap(\.totalTokens)
    guard !known.isEmpty else { return "tokens unknown" }
    let formatted = known.reduce(0, +).formatted(.number.notation(.compactName))
    return known.count == records.count ? "\(formatted) tokens" : "\(formatted) tokens + unknown"
}

private extension StoredMealAnalysisRoute {
    var isCloudProvider: Bool {
        switch self {
        case .openAI, .anthropic, .gemini, .vertexFallback: true
        default: false
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            Text(title)
                .font(.headline)
                .foregroundStyle(TracalColor.textPrimary)
                .padding(.horizontal, TracalSpace.xSmall)
            VStack(spacing: TracalSpace.medium) {
                content
            }
            .padding(TracalSpace.medium)
            .tonalSurface()
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String
    let systemImage: String
    var showsChevron = false
    var isDestructive = false

    var body: some View {
        HStack(spacing: TracalSpace.medium) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(isDestructive ? TracalColor.destructive : TracalColor.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(isDestructive ? TracalColor.destructive : TracalColor.textPrimary)
                if !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(TracalColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TracalColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: TracalMetric.minimumTapTarget)
        .contentShape(.rect)
    }
}
