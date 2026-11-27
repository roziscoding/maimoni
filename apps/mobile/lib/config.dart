/// Base URL of the maimoni server. Every API call is built from it (`$serverUrl/api/...`).
/// Override it in local builds with `--dart-define=SERVER_URL=...`: on the Android emulator,
/// `http://10.0.2.2` for the Docker dev stack (`mise run dev`), `http://10.0.2.2:3001` for the
/// backend run on the host (`mise run dev:backend`).
const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://maimoni.roz.ninja');

/// Google OAuth client IDs. The web one is the audience of the ID tokens the server accepts; the
/// iOS one identifies the app to Google's iOS SDK (its reversed form is a URL scheme in Info.plist).
/// Android needs no ID here, only an Android client for the package and signing key in the same project.
const googleWebClientId = '363526868858-6p105hdrhal86tag6thgd3ii8kgo6scj.apps.googleusercontent.com';
const googleIosClientId = '363526868858-7gqn6bphuvp9ub89mq1vuhjodibs7l3g.apps.googleusercontent.com';
