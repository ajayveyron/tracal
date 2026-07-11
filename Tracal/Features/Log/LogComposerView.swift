import PhotosUI
import SwiftUI
import UIKit

public struct LogComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: LogComposerViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCameraActive = false
    @State private var pendingCameraPhoto: CapturedCameraPhoto?
    @FocusState private var descriptionIsFocused: Bool

    private let onSave: @MainActor (AnalyzedMealDraft) -> Void

    @MainActor
    public init(
        initialDate: Date = .now,
        onSave: @escaping @MainActor (AnalyzedMealDraft) -> Void
    ) {
        _model = StateObject(
            wrappedValue: LogComposerViewModel(
                loggedAt: initialDate,
                analyzer: DefaultMealAnalysisRouter()
            )
        )
        self.onSave = onSave
    }

    @MainActor
    init(
        initialDate: Date = .now,
        analyzer: any MealAnalysisRouting,
        onSave: @escaping @MainActor (AnalyzedMealDraft) -> Void
    ) {
        _model = StateObject(
            wrappedValue: LogComposerViewModel(loggedAt: initialDate, analyzer: analyzer)
        )
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            captureView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let message = model.errorMessage {
                        AnalysisErrorView(
                            message: message,
                            recovery: model.recoveryMessage,
                            onRetry: {
                                if canAnalyze {
                                    model.analyzeMeal()
                                } else {
                                    model.clearError()
                                }
                            },
                            onDismiss: model.clearError
                        )
                        .padding(.horizontal, TracalSpace.medium)
                        .padding(.bottom, TracalSpace.small)
                    }
                }
        }
        .interactiveDismissDisabled(model.isAnalyzing || isCameraActive)
        .fullScreenCover(isPresented: $isCameraActive, onDismiss: ingestCapturedPhoto) {
            InlineMealCameraView(
                onCapture: { photo in
                    pendingCameraPhoto = photo
                    isCameraActive = false
                },
                onCancel: {
                    pendingCameraPhoto = nil
                    isCameraActive = false
                }
            )
            .ignoresSafeArea()
        }
        .task {
            model.loadLocalModelAvailability()
            model.ingestUITestFixtureIfPresent()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        model.reportPhotoLoadFailure()
                        return
                    }
                    model.ingestPhotoData(data, source: .photoLibrary)
                } catch {
                    model.reportPhotoLoadFailure()
                }
            }
        }
        .onChange(of: model.draft) { _, draft in
            guard draft != nil else { return }
            confirm()
        }
        .onDisappear {
            Task { await model.discard() }
        }
    }

    private var captureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TracalSpace.large) {
                VStack(alignment: .leading, spacing: TracalSpace.small) {
                    Text("Log meal")
                        .font(.largeTitle.bold())
                    Text("Describe it, add a photo, or both.")
                        .font(.subheadline)
                        .foregroundStyle(TracalColor.textSecondary)
                }

                descriptionSurface
                if model.previewImageData != nil {
                    photoPreviewSurface
                }

                if let availability = model.localModelAvailability,
                   availability != .available {
                    Text(availability.userMessage)
                        .font(.footnote)
                        .foregroundStyle(TracalColor.textSecondary)
                }
            }
            .frame(maxWidth: TracalMetric.contentMaxWidth)
            .padding(TracalSpace.large)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(TracalColor.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: TracalSpace.small) {
                imageSourceButtons
                analyzeButton
            }
            .padding(.horizontal, TracalSpace.large)
            .padding(.vertical, TracalSpace.small)
            .background(TracalColor.backgroundPrimary)
        }
        .overlay {
            if model.isAnalyzing {
                AnalysisActivityBorder(reduceMotion: reduceMotion)
                    .id(reduceMotion)
                    .padding(TracalSpace.xSmall)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Analyzing meal")
                    .accessibilityIdentifier("log.analysis.pulse")
            }
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    Task {
                        await model.discard()
                        dismiss()
                    }
                }
                .tint(TracalColor.accent)
            }
        }
    }

    private var descriptionSurface: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            Text("Description")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if model.typedDescription.isEmpty {
                    Text("Two eggs, toast, and a chai")
                        .foregroundStyle(TracalColor.textSecondary)
                        .padding(.horizontal, TracalSpace.xSmall)
                        .padding(.vertical, TracalSpace.small)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $model.typedDescription)
                    .focused($descriptionIsFocused)
                    .accessibilityIdentifier("log.description")
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 104)
                    .padding(.horizontal, -TracalSpace.xSmall)
                    .background(.clear)
                    .disabled(model.isAnalyzing)
            }
        }
        .padding(TracalSpace.medium)
        .tonalSurface()
    }

    private var photoPreviewSurface: some View {
        VStack(alignment: .leading, spacing: TracalSpace.medium) {
            Text("Image")
                .font(.headline)

            if let data = model.previewImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipShape(.rect(cornerRadius: TracalRadius.medium, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            Task {
                                await model.removePendingPhoto()
                                selectedPhoto = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .frame(
                                    width: TracalMetric.minimumTapTarget,
                                    height: TracalMetric.minimumTapTarget
                                )
                        }
                        .buttonStyle(.tracalGlass)
                        .clipShape(.circle)
                        .padding(TracalSpace.small)
                        .accessibilityLabel("Remove photo")
                        .accessibilityIdentifier("log.photo.remove")
                        .disabled(model.isAnalyzing)
                    }
                    .accessibilityLabel("Attached meal photo")
                    .accessibilityIdentifier("log.photo.preview")
            }

        }
        .padding(TracalSpace.medium)
        .tonalSurface()
    }

    private var imageSourceButtons: some View {
        HStack(spacing: TracalSpace.small) {
            Button {
                descriptionIsFocused = false
                pendingCameraPhoto = nil
                isCameraActive = true
            } label: {
                Label("Camera", systemImage: "camera")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.tracalGlass)
            .disabled(!CameraCaptureView.isAvailable || model.isAnalyzing)
            .accessibilityIdentifier("log.camera")

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.tracalGlass)
            .disabled(model.isAnalyzing)
            .accessibilityIdentifier("log.photos")
        }
    }

    private func ingestCapturedPhoto() {
        guard let photo = pendingCameraPhoto else { return }
        pendingCameraPhoto = nil
        let data = photo.originalData ?? photo.fallbackImage.flatMap(makeFallbackJPEG)
        guard let data, !data.isEmpty else {
            model.reportPhotoLoadFailure()
            return
        }
        model.ingestPhotoData(data, source: .cameraPhoto)
    }

    private func makeFallbackJPEG(from image: UIImage) -> Data? {
        let maximumDimension: CGFloat = 2_048
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, maximumDimension / longestSide)
        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(
            withCompressionQuality: 0.86
        ) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private var canAnalyze: Bool {
        !model.typedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.previewImageData != nil
    }

    private var analyzeButton: some View {
        Button(action: analyzeMeal) {
            HStack(spacing: TracalSpace.small) {
                if model.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(model.isAnalyzing ? "Analyzing…" : "Analyze meal")
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.tracalGlassProminent)
        .disabled(!canAnalyze || model.isAnalyzing)
        .accessibilityLabel(model.isAnalyzing ? "Analyzing meal" : "Analyze meal")
        .accessibilityIdentifier("log.analyze")
    }

    private func analyzeMeal() {
        descriptionIsFocused = false
        model.analyzeMeal()
    }

    private func confirm() {
        guard let draft = model.confirmedDraft() else { return }
        onSave(draft)
        dismiss()
    }
}

private struct AnalysisActivityBorder: View {
    let reduceMotion: Bool

    @State private var rotation = 0.0
    @State private var isPulsing = false

    var body: some View {
        RoundedRectangle(
            cornerRadius: TracalRadius.large + TracalSpace.xSmall,
            style: .continuous
        )
        .stroke(
            AngularGradient(
                colors: [
                    TracalColor.accent.opacity(0.18),
                    TracalColor.accent.opacity(0.95),
                    TracalColor.backgroundSecondary.opacity(0.72),
                    TracalColor.accent.opacity(0.54),
                    TracalColor.accent.opacity(0.18)
                ],
                center: .center,
                startAngle: .degrees(rotation),
                endAngle: .degrees(rotation + 360)
            ),
            lineWidth: 2.5
        )
        .shadow(
            color: TracalColor.accent.opacity(reduceMotion ? 0.28 : (isPulsing ? 0.42 : 0.20)),
            radius: reduceMotion ? 10 : (isPulsing ? 16 : 8)
        )
        .opacity(reduceMotion ? 0.82 : (isPulsing ? 1 : 0.68))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct AnalysisErrorView: View {
    let message: String
    let recovery: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(TracalColor.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                    if let recovery {
                        Text(recovery)
                            .font(.footnote)
                            .foregroundStyle(TracalColor.textSecondary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.tracalGlass)
                .accessibilityLabel("Dismiss")
            }
            Button("Try again", action: onRetry)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.tracalGlass)
                .accessibilityIdentifier("log.retry")
        }
        .padding(TracalSpace.medium)
        .background(TracalColor.backgroundSecondary)
        .clipShape(.rect(cornerRadius: TracalRadius.medium, style: .continuous))
    }
}
