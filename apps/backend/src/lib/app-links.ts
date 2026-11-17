import { Buffer } from 'node:buffer'
import process from 'node:process'
import { log } from './log'

/** What ties the mobile apps to this server's domain, for passkeys. */
export interface AppLinks {
  /** Android application ID and the SHA-256 fingerprints of the certificates that sign it. */
  android?: { packageName: string, fingerprints: string[] }
  /** `<team ID>.<bundle ID>` of the iOS app. */
  appleAppId?: string
}

const FINGERPRINT = /^[0-9A-F]{2}(?::[0-9A-F]{2}){31}$/

/**
 * Reads `ANDROID_APP_PACKAGE` and `ANDROID_APP_CERT_SHA256` (comma-separated fingerprints as
 * `keytool -list -v` prints them), and `APPLE_TEAM_ID` with `APPLE_APP_BUNDLE_IDENTIFIER`.
 */
export function appLinksFromEnv(env: Record<string, string | undefined> = process.env): AppLinks {
  const fingerprints = (env.ANDROID_APP_CERT_SHA256 ?? '').split(',').map(value => value.trim().toUpperCase()).filter(Boolean).filter((value) => {
    const valid = FINGERPRINT.test(value)
    if (!valid)
      log.withMetadata({ value }).error('ANDROID_APP_CERT_SHA256 has an entry that is not a SHA-256 fingerprint, ignored')
    return valid
  })
  const packageName = env.ANDROID_APP_PACKAGE?.trim()
  const teamId = env.APPLE_TEAM_ID?.trim()
  const bundleId = env.APPLE_APP_BUNDLE_IDENTIFIER?.trim()
  return {
    android: packageName && fingerprints.length ? { packageName, fingerprints } : undefined,
    appleAppId: teamId && bundleId ? `${teamId}.${bundleId}` : undefined,
  }
}

/** The origin Android puts in a passkey assertion made by an app signed with this certificate. */
export function androidOrigin(fingerprint: string) {
  return `android:apk-key-hash:${Buffer.from(fingerprint.replaceAll(':', ''), 'hex').toString('base64url')}`
}

/**
 * The passkey plugin's `origin`: the web origin, followed by one origin per Android signing
 * certificate, since Android reports a hash of the app's certificate instead of a URL.
 */
export function passkeyOrigins(origin: string | undefined, { android }: AppLinks) {
  const androidOrigins = (android?.fingerprints ?? []).map(androidOrigin)
  return androidOrigins.length && origin ? [origin, ...androidOrigins] : origin
}
