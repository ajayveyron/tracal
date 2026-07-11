import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyGoal.effectiveDate, order: .reverse) private var goals: [DailyGoal]

    @AppStorage("vertexGatewayURL") private var vertexGatewayURL = ""
    @State private var showingGoalEditor = false
    @State private var showingGatewaySetup = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionError: String?
    @State private var gatewayTokenIsStored = false

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
                        SettingsRow(
                            title: "Cloud analysis",
                            value: gatewayIsReady ? "Connected" : "Not connected",
                            systemImage: "sparkles"
                        )
                        SettingsRow(
                            title: "Offline fallback",
                            value: "Apple Intelligence when cloud is unavailable",
                            systemImage: "iphone.gen3"
                        )
                        Button {
                            showingGatewaySetup = true
                        } label: {
                            SettingsRow(
                                title: gatewayIsReady ? "Gateway details" : "Connect gateway",
                                value: gatewayHost,
                                systemImage: "lock.icloud",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.gateway")
                    }

                    SettingsSection(title: "Security") {
                        SettingsRow(
                            title: "App lock",
                            value: "Off while testing",
                            systemImage: "lock.open"
                        )
                    }

                    SettingsSection(title: "Data") {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            SettingsRow(
                                title: "Delete all data",
                                value: "",
                                systemImage: "trash",
                                isDestructive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Tracal keeps saved meals and goals on this iPhone. Failed analyses never change daily totals.")
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
            .sheet(isPresented: $showingGatewaySetup) {
                GatewaySetupSheet(
                    savedURL: $vertexGatewayURL,
                    tokenIsStored: gatewayTokenIsStored,
                    onSaved: {
                        gatewayTokenIsStored = true
                        showingGatewaySetup = false
                    },
                    onDisconnected: {
                        gatewayTokenIsStored = false
                        showingGatewaySetup = false
                    }
                )
                .presentationDetents([.large])
            }
            .confirmationDialog(
                "Delete every meal and goal?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete all data", role: .destructive, action: deleteAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
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
            .task {
                GatewayAutoProvision.applyIfNeeded()
                if vertexGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let provisioned = GatewayAutoProvision.resolvedBaseURL() {
                    vertexGatewayURL = provisioned.absoluteString
                }
                await refreshGatewayStatus()
            }
        }
    }

    private var gatewayIsReady: Bool {
        resolvedGatewayURL != nil && gatewayTokenIsStored
    }

    private var resolvedGatewayURL: URL? {
        if let stored = URL(string: vertexGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)),
           stored.host != nil {
            return stored
        }
        return VertexGatewayConfiguration.fromRuntime()?.baseURL
            ?? GatewayAutoProvision.resolvedBaseURL()
    }

    private var gatewayHost: String {
        resolvedGatewayURL?.host ?? ""
    }

    private var goalSummary: String {
        guard let currentGoal else { return "Not set" }
        return "\(currentGoal.calorieTarget.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: PendingAnalysis.self)
            try modelContext.delete(model: MealEntry.self)
            try modelContext.delete(model: DailyGoal.self)
            try modelContext.save()
            Task {
                await ProtectedMealImageStore().removeAll()
            }
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private func refreshGatewayStatus() async {
        do {
            _ = try await KeychainVertexGatewayAuthorizationProvider().authorization()
            gatewayTokenIsStored = true
        } catch {
            gatewayTokenIsStored = false
        }
    }
}

private struct GatewaySetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var savedURL: String

    let tokenIsStored: Bool
    let onSaved: () -> Void
    let onDisconnected: () -> Void

    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.large) {
                    VStack(alignment: .leading, spacing: TracalSpace.small) {
                        Text("Cloud analysis")
                            .font(.largeTitle.bold())
                        Text("Personal builds can auto-connect from Local.xcconfig. You can still paste a Vercel HTTPS URL and device token here. The token stays in this iPhone’s Keychain.")
                            .font(.subheadline)
                            .foregroundStyle(TracalColor.textSecondary)
                    }

                    VStack(spacing: TracalSpace.small) {
                        TextField("https://your-app.vercel.app", text: $endpoint)
                            .accessibilityIdentifier("gateway.url")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .padding(TracalSpace.medium)
                            .tonalSurface()

                        SecureField(
                            tokenIsStored ? "Leave blank to keep saved token" : "Device token",
                            text: $token
                        )
                        .accessibilityIdentifier("gateway.token")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(TracalSpace.medium)
                        .tonalSurface()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TracalColor.destructive)
                    }

                    Button(action: save) {
                        Text("Save private connection")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                        .accessibilityIdentifier("gateway.save")
                        .buttonStyle(.tracalGlassProminent)

                    if tokenIsStored {
                        Button(role: .destructive, action: disconnect) {
                            Text("Disconnect gateway")
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
            .navigationTitle("Gateway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(TracalColor.accent)
                }
            }
            .onAppear {
                endpoint = savedURL
            }
        }
    }

    private func save() {
        let endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: endpoint),
            url.scheme?.lowercased() == "https",
            url.host != nil,
            url.user == nil,
            url.password == nil,
            url.query == nil,
            url.fragment == nil
        else {
            errorMessage = "Use the HTTPS address of the private gateway."
            return
        }

        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tokenIsStored || !token.isEmpty else {
            errorMessage = "Paste the one-time device token."
            return
        }

        do {
            if !token.isEmpty {
                try VertexGatewayTokenStore().store(token)
            }
            savedURL = endpoint
            self.token = ""
            onSaved()
        } catch {
            errorMessage = "The device token could not be saved."
        }
    }

    private func disconnect() {
        do {
            try VertexGatewayTokenStore().delete()
            savedURL = ""
            token = ""
            onDisconnected()
        } catch {
            errorMessage = "The private connection could not be removed."
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
