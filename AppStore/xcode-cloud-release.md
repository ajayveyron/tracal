# Xcode Cloud release path

Use Xcode Cloud to create the App Store archive without downgrading the development Mac from macOS 27 beta.

## Local applications

Keep both applications with distinct names:

- `Xcode-27-beta.app` — supported GUI for the current macOS 27 beta; use it for development and the initial Xcode Cloud setup.
- `Xcode-26.6.app` — stable App Store toolchain; the GUI is not supported on macOS 27, but keep it for reference and command-line checks.

## Initial Xcode Cloud setup

The first Xcode Cloud workflow must be initialized from Xcode. Open the checked-in `Tracal.xcodeproj` with Xcode 27 beta, sign in to the Apple Account for team `626Z5FFYFU`, then:

1. Open the Report navigator.
2. Select the Cloud section and click **Get Started**.
3. Choose the Tracal product with bundle ID `com.ajaypawriya.tracal`.
4. Grant Xcode Cloud access to the private `ajayveyron/tracal` GitHub repository.
5. Name the workflow **App Store Release**.
6. Set the source branch to **public**. Do not build `main`, which remains the personal product baseline.
7. In **Environment**, select **Xcode 26.6** and an offered compatible macOS 26.x image. If Xcode 26.6 is not available in the menu, do not substitute Xcode 27 beta for the final App Store archive.
8. Add a Test action for the Tracal scheme on an available iPhone simulator.
9. Add an Archive action for iOS.
10. Configure distribution to TestFlight/App Store Connect and start the first build manually.

The project already has a checked-in shared scheme, automatic signing, explicit app and widget bundle identifiers, an enabled archive action, and no external build-time secrets.

## After the first cloud build

Manage later workflows from **App Store Connect → Tracal → Xcode Cloud → Manage Workflows**. Keep release builds manual and sourced from `public`.

When the archive succeeds:

1. Confirm it was produced with Xcode 26.6.
2. Confirm version `1.0.0` and an unused build number. The current candidate is build `14`; increment it if build 14 already exists in App Store Connect.
3. Distribute to internal TestFlight first.
4. Complete external TestFlight and release validation.
5. Select the cloud build for the 1.0 App Store version and submit with manual release.

Download and retain the archive and test-result artifacts. Xcode Cloud artifacts are not retained indefinitely.
