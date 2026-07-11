# App Review notes

Tracal is a paid, iPhone-only calorie tracker. It has no Tracal login, backend, remote database, advertising, or tracking SDK.

Meals, goals, protected photos, provider preferences, and usage history remain in the app sandbox. Provider API keys are entered by the user and stored with device-only Keychain protection.

Cloud analysis is optional and sends only the current meal description and sanitized photo directly to the provider selected in Settings: OpenAI, Anthropic, or Google Gemini. Provider API access and charges are separate from the paid App Store download.

Reviewers do not need to provide an API key. Use the bundled sample-meal path to inspect the complete result and persistence flow without a network request. Explicit nutrition text, history, editing, goals, backup, import, and deletion are also available without a provider account.

Apple processes purchases and refund requests. The app checks the signed app transaction without blocking legitimate customers when StoreKit is temporarily unavailable.
