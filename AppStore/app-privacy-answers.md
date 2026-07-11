# App Store privacy answers

Use these answers for App Store Connect version 1.0. They intentionally disclose the optional direct-provider data flow conservatively even though Tracal has no server and does not receive the requests.

## Data collection

Answer **Yes, we collect data from this app** because a user can choose to send meal data directly to OpenAI, Anthropic, or Google Gemini with their own API key.

Declare these categories:

| App Store category | Collected | Linked to user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Health — Health | Yes | Yes | No | App Functionality |
| User Content — Photos or Videos | Yes | Yes | No | App Functionality |
| User Content — Other User Content | Yes | Yes | No | App Functionality |

Choose **linked to the user** because the API key associates the direct request with the user’s provider account. Do not select analytics, product personalization, advertising, developer marketing, or tracking.

## Do not declare

- Local meals, goals, nutrition values, photos, and AI usage history that never leave the iPhone.
- Payment information or purchase history. Apple handles the paid download and Tracal never receives payment-card details.
- Contact information, identifiers, diagnostics, location, contacts, browsing history, or advertising data. Tracal does not collect them.
- API keys as a separate App Store category. They are stored device-only in Keychain and used only to authenticate the direct request selected by the user.

## Privacy-manifest match

`Tracal/Resources/PrivacyInfo.xcprivacy` declares the same three collected-data types as linked, not used for tracking, and used only for app functionality. It also declares the UserDefaults required-reason API with reason `CA92.1`.

## Disclosure text

Use this explanation if App Review asks why an app with no backend reports collected data:

> Tracal stores meal records locally and operates no developer server. When a user explicitly enables optional cloud analysis, the app sends only the current meal text or sanitized image directly from the iPhone to the user-selected provider using the user’s provider API key. Provider processing is disclosed conservatively as collection linked to the user for app functionality. Tracal has no tracking, advertising, or analytics SDK.

Reconcile these answers again before every release if providers, data flows, SDKs, or support channels change.
