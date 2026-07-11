# Tracal

Tracal is a native, local-first iPhone calorie tracker for iOS 26+. Meals, goals, protected photos, provider preferences, and usage history stay on the device.

Cloud estimates use the API provider explicitly selected by the user:

- OpenAI — `gpt-5.4-mini`
- Anthropic — `claude-haiku-4-5-20251001`
- Gemini — `gemini-3.5-flash`

Requests go directly to the provider’s official HTTPS API. Tracal has no account system, inference backend, remote meal database, CloudKit sync, advertising, or third-party analytics.

## Privacy boundary

- Provider credentials use `WhenUnlockedThisDeviceOnly` Keychain protection.
- No provider key is stored in SwiftData, UserDefaults, backups, logs, crash metadata, source, or the app bundle.
- Photos are orientation-normalized, metadata-stripped, resized to at most 2048 px, and re-encoded before local storage or cloud analysis.
- Deterministic nutrition parsing and Vision label OCR run locally first.
- Apple Intelligence remains the offline text fallback on eligible devices.
- Tracal never automatically moves a request to another cloud provider.

## Usage and cost estimates

Every billable provider attempt has a local `AIUsageRecord`. Tracal normalizes input, output, cached, cache-write, reasoning, and total token counts when the provider reports them. Settings shows monthly and all-time totals, provider breakdowns, recent request status, and estimated USD cost.

Cost estimates use the versioned public price catalog in `ModelPricingCatalog.swift`. Free tiers, negotiated discounts, taxes, and later provider pricing changes can differ; provider dashboards are authoritative.

## Backups

Settings can export a versioned `.tracalbackup` file containing meals, goals, protected images, and usage history. API keys are never exported. Import adds records that are not already present on the device.

## Development

Open the checked-in Xcode project:

```sh
open -a "$HOME/Downloads/Xcode-beta.app" "$PWD/Tracal.xcodeproj"
```

The current project uses automatic signing for team `626Z5FFYFU`, bundle ID `com.ajaypawriya.tracal`, and an iPhone-only iOS 26 deployment target. `xcodegen generate` is needed only after project metadata or source membership changes.

When command-line tools do not point at the full beta Xcode, prefix commands with:

```sh
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer"
```

Core checks:

```sh
./scripts/test_core.sh
```

Do not add provider keys to schemes, xcconfig files, environment files, or test fixtures. Use the in-app Settings flow and dedicated low-limit test keys.

## Release preparation

- Product and implementation plan: [`plan.html`](plan.html)
- App Store metadata: [`AppStore/metadata.md`](AppStore/metadata.md)
- App Review notes: [`AppStore/review-notes.md`](AppStore/review-notes.md)
- Release checklist: [`AppStore/release-checklist.md`](AppStore/release-checklist.md)
- Static privacy, terms, API-key safety, provider billing, refund, and support pages: [`public-site`](public-site)

The app is planned as a US $8.99 one-time paid download. Provider API access and charges are separate from the App Store purchase. Nutrition estimates are not medical advice.
