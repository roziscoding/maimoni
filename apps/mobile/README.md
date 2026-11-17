# maimoni mobile

Flutter client for the maimoni server, with the same pages as the web app. The server URL is
`serverUrl` in `lib/config.dart`.

`lib/domain` is a Dart port of `packages/shared` (summary, expressions, daily spends): the app
recomputes the month summary locally, like the web. Keep both in sync; `test/domain_test.dart`
mirrors the shared tests.

## Sign in

- The app needs an account on the server at `serverUrl`.
- Sign in is by email and password.
- The session token is stored with `flutter_secure_storage`. The Android manifest turns auto backup
  off because a restored token can't be decrypted on another install.

## Tasks

Run from the repository root. iOS tasks only work on macOS.

- **`mise run mobile:run:android`**: boots the `maimoni` emulator (created by `mobile:setup:emulator`) and runs the app with hot reload.
- **`mise run mobile:run:ios`**: same, on the iOS Simulator.
- **`mise run mobile:build`**: release builds for both platforms (`mobile:build:android`, `mobile:build:ios`).
- **`mise run mobile:build:ipa`**: signed IPA for TestFlight; pass `--export-options-plist`.
- **`mise run mobile:install:android`** / **`mobile:install:ios`**: build and install on the connected device.
- **`mise run mobile:check`**: analyzer and tests.
- **`mise run mobile:branding`**: regenerates icons and splash from `assets/branding`.

## Releases

Code moves `main -> beta -> stable`, only by fast-forward, so stable only ever gets code that was
released as a beta first. The ***Actions -> Mobile release*** workflow, run on `main`, does one
step:

- **`beta`**: moves `beta` to `main`'s commit.
- **`stable`**: moves `stable` to `beta`'s commit.

It then starts ***Mobile publish*** on that branch:

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

- **Android, in the app:** ***Configurações -> Atualizações*** shows the installed version, the
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
  `~/.config/ios-build/keychain-password` exists.
