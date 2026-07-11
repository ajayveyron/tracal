import SwiftUI

struct DateStrip: View {
    @Binding var selectedDate: Date
    let calendar: Calendar

    @State private var visibleAnchor: Date

    init(selectedDate: Binding<Date>, calendar: Calendar = .current) {
        _selectedDate = selectedDate
        self.calendar = calendar
        _visibleAnchor = State(
            initialValue: calendar.startOfDay(for: selectedDate.wrappedValue)
        )
    }

    private var dates: [Date] {
        (-2...2).compactMap {
            calendar.date(byAdding: .day, value: $0, to: visibleAnchor)
        }
    }

    private var todayIsBeforeVisibleDates: Bool {
        guard let firstDate = dates.first else { return false }
        return calendar.startOfDay(for: .now) < firstDate
    }

    private var todayIsAfterVisibleDates: Bool {
        guard let lastDate = dates.last else { return false }
        return calendar.startOfDay(for: .now) > lastDate
    }

    var body: some View {
        HStack(spacing: TracalSpace.xSmall) {
            navigationButton(
                systemImage: "chevron.left",
                dayOffset: -5,
                pointsTowardToday: todayIsBeforeVisibleDates,
                accessibilityIdentifier: "today.dates.previous",
                accessibilityLabel: "Previous dates"
            )

            ForEach(dates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)

                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        selectedDate = calendar.startOfDay(for: date)
                    }
                } label: {
                    VStack(spacing: TracalSpace.xSmall) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                isSelected
                                    ? TracalColor.accentForeground
                                    : (isToday ? TracalColor.accent : TracalColor.textSecondary)
                            )

                        Text(date, format: .dateTime.day())
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(
                                isSelected ? TracalColor.accentForeground : TracalColor.textPrimary
                            )

                        Circle()
                            .fill(isSelected ? TracalColor.accentForeground : TracalColor.accent)
                            .frame(width: 4, height: 4)
                            .opacity(isToday ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .contentShape(.rect)
                }
                .buttonStyle(
                    TracalGlassButtonStyle(role: isSelected ? .prominent : .standard)
                )
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityIdentifier(
                    "today.date.\(Int(calendar.startOfDay(for: date).timeIntervalSince1970))"
                )
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }

            navigationButton(
                systemImage: "chevron.right",
                dayOffset: 5,
                pointsTowardToday: todayIsAfterVisibleDates,
                accessibilityIdentifier: "today.dates.next",
                accessibilityLabel: "Next dates"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Swipe left or right to show five more days")
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 48 else { return }
                    page(by: value.translation.width < 0 ? 5 : -5)
                }
        )
        .onChange(of: selectedDate) { _, newDate in
            guard !contains(newDate) else { return }
            withAnimation(.snappy(duration: 0.28)) {
                visibleAnchor = calendar.startOfDay(for: newDate)
            }
        }
    }

    private func navigationButton(
        systemImage: String,
        dayOffset: Int,
        pointsTowardToday: Bool,
        accessibilityIdentifier: String,
        accessibilityLabel: String
    ) -> some View {
        Button {
            page(by: dayOffset)
        } label: {
            VStack(spacing: TracalSpace.xSmall) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))

                Circle()
                    .fill(TracalColor.accentForeground)
                    .frame(width: 4, height: 4)
                    .opacity(pointsTowardToday ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
        }
        .buttonStyle(
            TracalGlassButtonStyle(role: pointsTowardToday ? .prominent : .standard)
        )
        .accessibilityLabel(
            pointsTowardToday ? "\(accessibilityLabel), Today is this way" : accessibilityLabel
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func contains(_ date: Date) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    private func page(by dayOffset: Int) {
        guard let newAnchor = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: visibleAnchor
        ), let newSelection = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: selectedDate
        ) else { return }

        withAnimation(.snappy(duration: 0.28)) {
            visibleAnchor = calendar.startOfDay(for: newAnchor)
            selectedDate = calendar.startOfDay(for: newSelection)
        }
    }
}
