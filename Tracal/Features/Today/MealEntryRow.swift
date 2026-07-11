import SwiftUI
import UIKit

struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(spacing: TracalSpace.medium) {
            MealThumbnail(entry: entry)

            VStack(alignment: .leading, spacing: TracalSpace.xSmall) {
                Text(entry.title.isEmpty ? "Untitled meal" : entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TracalColor.textPrimary)
                    .lineLimit(2)

                HStack(spacing: TracalSpace.xSmall) {
                    Text(entry.loggedAt, format: .dateTime.hour().minute())
                    if entry.state != .confirmed {
                        Text("·")
                        Text(stateLabel)
                    }
                }
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
            }

            Spacer(minLength: TracalSpace.small)

            Text(entry.caloriesKcal, format: .number.precision(.fractionLength(0)))
                .font(.body.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(TracalColor.textPrimary)
                .contentTransition(.numericText())

            Text("kcal")
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .padding(TracalSpace.medium)
        .tonalSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.meal")
        .accessibilityValue(entry.analysisRouteRawValue)
    }

    private var stateLabel: String {
        switch entry.state {
        case .draft: "Draft"
        case .pending: "Analyzing"
        case .needsReview: "Estimate flagged"
        case .confirmed: "Confirmed"
        case .failed: "Needs attention"
        }
    }
}

private struct MealThumbnail: View {
    let entry: MealEntry

    var body: some View {
        Group {
            if let image = loadThumbnail() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if entry.state == .pending {
                ProgressView()
                    .tint(TracalColor.accent)
            } else {
                Image(systemName: entry.inputSource.systemImage)
                    .font(.headline)
                    .foregroundStyle(TracalColor.accent)
            }
        }
        .frame(width: 54, height: 54)
        .background(TracalColor.backgroundTertiary)
        .clipShape(.rect(cornerRadius: TracalRadius.small, style: .continuous))
        .accessibilityHidden(true)
    }

    private func loadThumbnail() -> UIImage? {
        guard let relativePath = entry.thumbnailRelativePath else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = documents?.appending(path: relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
