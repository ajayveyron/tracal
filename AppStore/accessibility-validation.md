# Accessibility validation

Version 1.0 includes code support for VoiceOver, Dynamic Type, Reduce Motion, and keyboard access. Automated checks reduce regressions, but the App Store accessibility declarations should not be published until the remaining manual checks pass on the release candidate.

## Implemented

### VoiceOver

- Major screen and section headings expose heading traits.
- Icon-only controls, the date strip, meal rows, photos, progress state, settings rows, and widget actions have explicit labels, values, hints, or hidden decorative imagery.
- Meal rows are real buttons with accessible edit, duplicate, and delete actions instead of tap-gesture-only controls.
- The system Camera and Photos interfaces retain Apple’s native accessibility behavior.

### Dynamic Type

- Text uses semantic styles or `@ScaledMetric` for custom numeric displays.
- Today and History headers, date navigation, meal rows, calorie and macro summaries, goal fields, stored nutrition, and composer source buttons switch to vertical or horizontally scrollable layouts at accessibility text sizes.
- The UI-test launch configuration can force `.accessibility5`, the largest SwiftUI Dynamic Type size.

### Reduce Motion

- Analysis activity stops its repeating rotation and pulse.
- Date selection and paging, month changes, calorie progress, and numeric transitions disable custom animation when Reduce Motion is enabled.
- The accessibility UI-test configuration forces Reduce Motion on.

### Keyboard

- Meal rows use focusable system buttons.
- Composer, goal, provider, and meal-title inputs have explicit focus state and keyboard dismissal.
- Decimal-pad forms expose a Done button; hardware Return advances between goal fields.
- Meal editing supports Command-S to save and Escape to cancel.
- UI tests cover composer and goal-keyboard dismissal.

## Automated release checks

- The `Public iOS validation` GitHub Actions workflow runs these checks on a `macos-26` runner with Xcode 26.6 for every push to `public`.
- Run `TracalUITests/testAccessibilityAtLargestTextSize` on an iPhone simulator. It audits Dynamic Type, clipped text, element descriptions, hit regions, and traits on Today and Log Meal.
- Run `TracalUITests/testGoalEditorKeyboardCanBeDismissed`.
- Run the existing composer keyboard-layout test.

## Manual release checks

- Navigate every screen with VoiceOver enabled; verify order, labels, values, hints, modal focus, custom actions, and announcements.
- Run Accessibility Inspector audits on Today, Log Meal, History, Meal, Settings, Daily Goal, Provider, and AI Usage.
- Test the smallest text size and every accessibility text size without clipping, overlap, hidden controls, or horizontal truncation.
- Enable Reduce Motion and confirm no automatic or repetitive custom motion remains.
- Enable Full Keyboard Access with a hardware keyboard and complete logging, editing, settings, provider setup, backup, and deletion without touch.
- Repeat the critical flows on a physical iPhone before publishing accessibility support in App Store Connect.
