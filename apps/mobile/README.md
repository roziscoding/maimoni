# maimoni mobile

Flutter client for the maimoni server, with the same pages as the web app. The server URL is
`serverUrl` in `lib/config.dart`.

`lib/domain` is a Dart port of `packages/shared` (summary, expressions, daily spends): the app
recomputes the month summary locally, like the web. Keep both in sync; `test/domain_test.dart`
mirrors the shared tests.

## Sign in

- The app needs an account on the server at `serverUrl`.
- Sign in is by email and password, Google, Apple or a passkey.
- ***Esqueceu a senha?*** asks the server for a reset link. The new password is set on the web page
  the link opens.
- ***Continuar com o Google*** appears when the server lists Google. It needs, in the Google Cloud project
  of the web client:
  - an Android OAuth client for `ninja.roz.maimoni` with the SHA-1 of each signing key. A build
    signed with a key that has no Android client behaves as if the person cancelled.
  - an iOS OAuth client for the bundle ID. The server needs its ID in `GOOGLE_IOS_CLIENT_ID`.
- The Google client IDs live in `lib/config.dart`, and the iOS URL scheme in `ios/Runner/Info.plist`.
- ***Continuar com a Apple*** appears on iOS only, when the server lists Apple, above the other
  buttons. It needs the Sign in with Apple capability on the App ID and
  `APPLE_APP_BUNDLE_IDENTIFIER` on the server.
- Both buttons follow their provider's guidelines
  ([Google](https://developers.google.com/identity/branding-guidelines),
  [Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)), in
  `lib/widgets/sign_in_buttons.dart`:
  - Google's is drawn by the app. Its "G" in `assets/sign-in` is cut from the light theme's
    logo-only button of Google's `signin-assets.zip`.
  - Apple's is the `sign_in_with_apple` package's button, which draws the logo itself.
- ***Entrar com passkey*** is always shown on Android and iOS. It signs in with a passkey that
  already exists for the server's domain; the app doesn't create passkeys.
  - It needs Android 9 or iOS 16.
  - The server needs `ANDROID_APP_PACKAGE` and `ANDROID_APP_CERT_SHA256`, with one fingerprint per
    signing key as `keytool -list -v -keystore <keystore>` prints it. With them the domain serves
    `/.well-known/assetlinks.json`.
  - The server needs `APPLE_TEAM_ID` and `APPLE_APP_BUNDLE_IDENTIFIER` for iOS. With them the domain
    serves `/.well-known/apple-app-site-association`.
  - On iOS the App ID needs the Associated Domains capability. The domain is in
    `ios/Runner/Runner.entitlements` (`webcredentials:<host>`) and has to match `serverUrl`, so
    changing `serverUrl` means changing that entitlement too.
- The session token is stored with `flutter_secure_storage`. The Android manifest turns auto backup
  off because a restored token can't be decrypted on another install.

## Tasks

Run from the repository root. iOS tasks only work on macOS.

- **`mise run mobile:run:android`**: boots the `maimoni` emulator (created by `mobile:setup:emulator`) and runs the app with hot reload.
- **`mise run mobile:run:ios`**: same, on the iOS Simulator.
- **`mise run mobile:preview:android`** / **`mobile:preview:ios`**: runs the app against [fake data](#preview-with-fake-data), with no backend.
- **`mise run mobile:build`**: release builds for both platforms (`mobile:build:android`, `mobile:build:ios`).
- **`mise run mobile:build:ipa`**: signed IPA for TestFlight; pass `--export-options-plist`.
- **`mise run mobile:install:android`** / **`mobile:install:ios`**: build and install on the connected device.
- **`mise run mobile:check`**: analyzer and tests.
- **`mise run mobile:branding`**: regenerates icons and splash from `assets/branding`.

## Preview with fake data

`mise run mobile:preview:android` (or `mobile:preview:ios`) runs `preview/main.dart` instead of the
app's own entrypoint. It starts signed in and answers every request from a fake server kept in
memory, so every screen can be opened and used without a backend or an account. The development
backend has sign up turned off, which makes this the quickest way to look at a UI change.

- **Data:** built around today's date.
  - This month has today open and spends on every day before it.
  - Three earlier months are closed, one of them a year back.
  - The currencies are EUR (main) and BRL.
  - One item is an estimate waiting to be confirmed and another has no amount.
- **Changes:** adding, editing and deleting work, and are lost when the app closes.
- **Login screen:** pass `--dart-define=PREVIEW_SIGNED_OUT=true` to start signed out. Signing in
  doesn't work there: the fake server has no auth routes.
- **Arguments:** anything after the task name goes to `flutter run`.
- **Builds:** the file is outside `lib/` and nothing imports it, so no build of the real app
  includes it. `mobile:check` still analyzes it.

A screenshot of the running emulator: `adb exec-out screencap -p > screen.png`. The emulator also
runs without a window (`emulator -avd maimoni -no-window`), which is enough for screenshots.

## Releases

Code moves `main -> beta -> stable`, only by fast-forward, so stable only ever gets code that was
released as a beta first. The ***Actions -> Mobile release*** workflow, run on `main`, does one
step:

- **`beta`**: moves `beta` to `main`'s commit.
- **`stable`**: moves `stable` to `beta`'s commit.

It then publishes from that branch:

1. semantic-release picks the version from the conventional commits that touch the app
   (`release/semantic-release.ts` filters them by path): `X.Y.Z-beta.N` on beta, `X.Y.Z` on stable.
   A `fix` makes a patch version and a `feat` a minor one, the same as for any release.
2. The APK and the iOS build are made with that version. The iOS build goes to TestFlight.
3. Once both succeed, the `mobile-vX.Y.Z` tag and GitHub release are published with the APK. Betas
   are GitHub prereleases.

`appVersion` in `packages/shared/src/app-version.ts` maps the version to each platform: Android's
versionName is the version itself, iOS's is `X.Y.Z` (it takes no prerelease), and both share the
build number `MAJOR·1000000 + MINOR·10000 + PATCH·100 + (N for beta.N, 99 for stable)`, so a beta
always sorts below the stable release that follows it.

## Updates

- **Android, in the app:** ***Ajustes -> Atualizações*** shows the installed version, the
  channel (stable, or beta for betas first) and newer releases. The app checks on launch, then
  downloads the APK and opens the system installer. It asks the server
  (`GET /api/app/android/latest`), which reads the private repository's releases with its
  `GITHUB_RELEASES_TOKEN`; downloads are redirected straight to GitHub.
- **Android, with Obtainium:** add the repository as a GitHub source with a personal access token
  (the repository is private). Turn on ***Include prereleases*** to get betas, and set
  ***Filter release titles by regular expression*** to `^mobile-v` so releases of other apps are
  skipped.
- **iOS:** TestFlight, which can update the app automatically.

## Signing

- **CI secrets:** the publish workflow reads the signing material from the `mobile-signing` item in
  the `maimoni` 1Password vault, through a service account. The repository holds a single secret,
  `OP_SERVICE_ACCOUNT_TOKEN`.
- **Android:** release builds are signed with the key in `android/key.properties` (gitignored; CI
  writes it from the keystore and password in 1Password). Every published APK must use the same
  key, or installed apps refuse the update. Without the file, release builds use the debug key.
- **iOS:** CI fetches the App Store certificate and profile through the App Store Connect API
  (`.github/actions/ios-signing`) and exports for the App Store. On the Mac, over SSH, signing reads
  from the `ios-build` keychain, which `mobile:setup:ios-keychain` unlocks when
  `~/.config/ios-build/keychain-password` exists. The App ID needs the Sign in with Apple and
  Associated Domains capabilities, since the profile CI fetches has to carry both entitlements.
