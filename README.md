# Tracal

Tracal is a private, native iPhone calorie tracker. It saves analyzed meals locally and sends new estimates only to a user-configured private Vertex gateway. Explicit nutrition and labels stay local; Apple Intelligence is the offline fallback.

## Current build

The app includes SwiftUI and SwiftData, one text-and-image logging flow, deterministic nutrition math, Vision nutrition-label OCR, iOS 26 on-device text analysis, availability-gated iOS 27 on-device meal-photo analysis, a private `/v1/analyze` gateway client, and a Face ID/device-passcode app lock. No gateway address, bearer token, Vertex credential, API key, or service-account file is bundled.

## Run on the personal iPhone 17

### Prerequisites

- Xcode 27 beta 3 at `~/Downloads/Xcode-beta.app` (the current local build reports `27A5218g`). Launch it once so Xcode can finish installing components.
- The iPhone 17 on iOS 26 or later, unlocked and connected by cable for the first pairing.
- The Apple developer account for team `626Z5FFYFU` available in Xcode. The project already uses automatic signing, bundle ID `com.ajaypawriya.tracal`, and an iPhone-only iOS 26 deployment target.
- A device passcode. Face ID is recommended. Apple Intelligence must be enabled and its model downloaded to use the offline language-model paths.

### Install and launch

1. From this repository, open the checked-in project with the beta Xcode:

   ```sh
   open -a "$HOME/Downloads/Xcode-beta.app" "$PWD/Tracal.xcodeproj"
   ```

2. Connect and unlock the iPhone. Tap **Trust** on the phone if asked. If Xcode requests it, enable **Settings → Privacy & Security → Developer Mode**, restart the phone, and confirm Developer Mode after reboot.
3. Select the **Tracal** target and check **Signing & Capabilities**. Keep **Automatically manage signing** enabled, select team `626Z5FFYFU`, and keep `com.ajaypawriya.tracal` unless that identifier is unavailable to the selected team.
4. Select the physical iPhone 17 as the Tracal scheme’s run destination and build the app. For routine development updates, install the resulting `.app` with the guarded command below instead of deleting the phone app or using Device Hub. If iOS shows an untrusted-developer prompt, approve the development profile under **Settings → General → VPN & Device Management**, then launch again.
5. On first launch, allow Face ID. Tracal uses device-owner authentication, so the device passcode remains the fallback. The app locks again after it enters the backgro und. Camera permission is requested only when Camera is used; Photos uses the system picker.

The existing `Tracal.xcodeproj` is ready to open; `xcodegen generate` is only needed after project metadata or source membership changes. If command-line builds are needed while `xcode-select` points at Command Line Tools, set `DEVELOPER_DIR=$HOME/Downloads/Xcode-beta.app/Contents/Developer` for that command.

### Data-preserving device install

Quit Xcode Device Hub, keep the existing Tracal app installed, then pass the newly built `.app` to:

```sh
./scripts/install-device-preserving-data.sh "/absolute/path/to/Tracal.app"
```

The script refuses to install while Device Hub is running, copies the current Application Support, Documents, and Preferences data to `~/Library/Application Support/TracalDeviceBackups`, installs over the unchanged `com.ajaypawriya.tracal` bundle ID, then checks database integrity, byte fingerprints, and goal, meal, and item counts. If verification fails, do not open Tracal; the script prints the exact pre-install backup location.

## Analysis setup choices

### Local-only

Gateway pairing is optional. Without it, Today, History, goals, edits, deletion, explicitly stated calorie/macro values, and nutrition-label OCR remain local. Apple Intelligence can analyze ordinary text offline on iOS 26+. Ordinary meal photos require the private gateway; the iOS 27 beta on-device multimodal fallback is disabled because its image-attachment path can terminate the app on physical hardware. If the gateway is unavailable, the photo stays in the composer for retry. Non-food photos show an inline error and are never saved.

### Personal production on Vercel — recommended for this phone

Production gateway (already set up for this project):

`https://tracal-meal-gateway.vercel.app`

`Config/Local.xcconfig` (gitignored) auto-pairs the iPhone build with that URL
and device token. Rebuild Tracal from Xcode onto your phone — no Settings paste.

If you need to redeploy or rotate the token:

```sh
cd vertex-meal-gateway
npx vercel --prod
# rotate: npm run setup:personal, update Vercel env digest, then:
npm run setup:personal -- --url https://tracal-meal-gateway.vercel.app --write-xcconfig --force
xcodegen generate
```

Details in `vertex-meal-gateway/README.md`.

### Private Cloud Run gateway

The original path is the service in `vertex-meal-gateway` deployed to Cloud Run:

1. Enable Vertex AI in a dedicated GCP project.
2. Deploy the included Dockerfile with a dedicated Cloud Run service identity. Grant that identity only the Vertex AI role required by the selected model; Cloud Run supplies Application Default Credentials, so no GCP key belongs in the app, repository, image, or environment file.
3. Configure the gateway with `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, and `TRACAL_DEVICE_TOKEN_SHA256`. `TRACAL_MODEL` is optional. Configure only the one-way token digest on Cloud Run.
4. Because this one-user iPhone client does not mint Google-signed Cloud Run ID tokens, permit network invocation at the Cloud Run layer and rely on the gateway’s high-entropy per-install bearer check as the application boundary.
5. Generate a one-time device token with `npm run token` inside `vertex-meal-gateway`. Put the raw value only into Tracal’s secure pairing screen; put only its displayed digest on Cloud Run, then clear the raw value from the clipboard.
6. In Tracal, open **Settings → Connect gateway**, paste the Cloud Run HTTPS base URL and the one-time device token, then choose **Save private connection**. The URL stays in UserDefaults and the token uses `WhenUnlockedThisDeviceOnly` Keychain protection.

See `vertex-meal-gateway/README.md` for deployment variables, request limits, ADC setup, and the mocked gateway test suite.

### Local gateway development

The loopback bypass is for the iOS Simulator only. Start the local service with its documented debug-only bypass and set these Tracal scheme variables:

```text
TRACAL_GATEWAY_BASE_URL=http://127.0.0.1:8080
TRACAL_ALLOW_INSECURE_LOCAL=true
```

On a physical iPhone, `127.0.0.1` and `localhost` refer to the phone—not this Mac. The current client also rejects insecure LAN addresses, so replacing loopback with the Mac’s Wi-Fi IP will not work. Use the Cloud Run HTTPS endpoint for the normal phone flow, or deliberately place the local service behind a secured HTTPS tunnel for temporary device testing and keep bearer authentication enabled.

## Storage, updates, and reinstall behavior

- SwiftData keeps meals, food items, goals, and pending metadata in the app sandbox. There is no CloudKit sync or remote meal database.
- Original file bytes are not persisted. Tracal retains a protected, orientation-normalized copy with source metadata removed, resized to at most 2048 px and re-encoded under `Documents/ProtectedMealDrafts`; reopening the meal shows that retained source image alongside the exact written description.
- Running a new build from Xcode over the same bundle ID normally preserves the sandbox, UserDefaults, protected images, and Keychain pairing. Cleaning the Xcode build folder does not erase phone data.
- For this development phone, use `scripts/install-device-preserving-data.sh` for every update. A controlled reinstall through `devicectl` preserved the SwiftData store and WAL byte-for-byte; the script adds a pre-install external backup plus post-install integrity, fingerprint, and record-count verification.
- Deleting Tracal from the iPhone removes its SwiftData store, settings, and protected image files. Keychain items can survive app deletion; after reinstalling the same bundle ID, re-enter the gateway URL and disconnect or rotate the gateway token if a clean security reset is required.
- Changing the bundle ID installs a separate app with a separate sandbox and does not migrate existing meals.
- **Settings → Delete all data** removes meals, goals, pending records, and protected meal images, but gateway pairing is separate. Use **Disconnect gateway** to remove the saved URL and Keychain token.
- Export and crash-safe background retry are not implemented yet, so deleting the app or using Delete all data is irreversible.

For an install that does not depend on development provisioning, archive and distribute a private build through TestFlight.

## Development checks

```sh
./scripts/test_core.sh
cd vertex-meal-gateway && npm test
```

The shared `vertex-image-gen` environment is not an application credential source. Runtime Vertex access uses only the private gateway and its dedicated service identity.
