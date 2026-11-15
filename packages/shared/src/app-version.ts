/**
 * Versions of the mobile app. semantic-release picks a version (e.g. 1.3.0-beta.2) and each
 * platform builds with what it accepts: Android's versionName is the version itself, iOS's
 * CFBundleShortVersionString only takes MAJOR.MINOR.PATCH, and both share one build number.
 *
 * Kept free of other imports: the release tooling loads it directly with Node's type stripping.
 */

export interface AppVersion {
  /** The release version, also Android's versionName. */
  version: string
  /** iOS's CFBundleShortVersionString. */
  iosVersion: string
  /** Build number for both platforms (Android's versionCode, iOS's CFBundleVersion). */
  code: number
}

/** Release tags of the mobile app look like `mobile-v1.3.0` or `mobile-v1.4.0-beta.2`. */
export const appTagPrefix = 'mobile-v'

/**
 * MAJOR·1000000 + MINOR·10000 + PATCH·100 + 99 for a stable release, or + N for its Nth prerelease
 * (1.3.0-beta.2 → 1030002). Every prerelease of a version sorts below the version itself, so an
 * installed beta always accepts the stable release that follows it.
 */
export function appVersion(version: string): AppVersion {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-[a-z]+\.(\d+))?$/.exec(version)
  if (!match)
    throw new Error(`Unsupported app version: ${version}`)
  const [major, minor, patch, prerelease] = match.slice(1).map(part => part === undefined ? undefined : Number(part)) as [number, number, number, number | undefined]
  if (minor > 99 || patch > 99 || (prerelease ?? 0) > 98)
    throw new Error(`App version ${version} doesn't fit the build number scheme (minor, patch ≤ 99; prerelease ≤ 98)`)
  return {
    version,
    iosVersion: `${major}.${minor}.${patch}`,
    code: major * 1_000_000 + minor * 10_000 + patch * 100 + (prerelease ?? 99),
  }
}

/** The version in a release tag, or `null` when the tag isn't a mobile app release. */
export function appVersionFromTag(tag: string): AppVersion | null {
  if (!tag.startsWith(appTagPrefix))
    return null
  try {
    return appVersion(tag.slice(appTagPrefix.length))
  }
  catch {
    return null
  }
}

/** Whether a build number belongs to a prerelease (stable builds end in 99). */
export function isPrereleaseCode(code: number) {
  return code % 100 !== 99
}
