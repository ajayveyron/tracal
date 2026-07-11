import SwiftUI
import UIKit
import WidgetKit

@main
struct TracalQuickLogWidget: Widget {
    private let kind = "TracalQuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogTimelineProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Open Tracal with text, Camera, or Photos ready.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct QuickLogEntry: TimelineEntry {
    let date: Date
}

private struct QuickLogTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(QuickLogEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        completion(Timeline(entries: [QuickLogEntry(date: .now)], policy: .never))
    }
}

private struct QuickLogWidgetView: View {
    let entry: QuickLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title3)
                    .foregroundStyle(WidgetPalette.accent)
                    .accessibilityHidden(true)
                Text("Log meal")
                    .font(.headline)
                Spacer(minLength: 0)
                Text("Tracal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetPalette.textSecondary)
            }

            HStack(spacing: 8) {
                QuickLogAction(title: "Text", systemImage: "text.cursor", mode: "text")
                QuickLogAction(title: "Camera", systemImage: "camera.fill", mode: "camera")
                QuickLogAction(title: "Gallery", systemImage: "photo.on.rectangle", mode: "gallery")
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetPalette.background
        }
    }
}

private struct QuickLogAction: View {
    let title: String
    let systemImage: String
    let mode: String

    var body: some View {
        Link(destination: URL(string: "tracal://log/\(mode)")!) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WidgetPalette.surface)
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log meal with \(title)")
    }
}

private enum WidgetPalette {
    static let background = Color(light: 0xF4F2EC, dark: 0x121713)
    static let surface = Color(light: 0xE5E9E2, dark: 0x202821)
    static let textPrimary = Color(light: 0x172019, dark: 0xEFF3EF)
    static let textSecondary = Color(light: 0x626A63, dark: 0xAAB5AC)
    static let accent = Color(light: 0x2E7049, dark: 0x83D09E)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}
