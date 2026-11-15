import { appVersionFromTag } from '@maimoni/shared'
import { z } from 'zod'
import { log } from '../lib/log'

const releasesSchema = z.array(z.object({
  tag_name: z.string(),
  draft: z.boolean(),
  prerelease: z.boolean(),
  body: z.string().nullable(),
  published_at: z.string().nullable(),
  assets: z.array(z.object({
    id: z.number(),
    name: z.string(),
    /** `sha256:<hex>`; GitHub fills it for assets uploaded since mid-2025. */
    digest: z.string().nullish(),
  })),
}))

export type AppChannel = 'stable' | 'beta'

export interface AndroidRelease {
  tag: string
  version: string
  versionCode: number
  prerelease: boolean
  notes: string | null
  publishedAt: string | null
  apk: { id: number, name: string, sha256: string | null }
}

export interface AppReleaseServiceOptions {
  /** GitHub token that can read the repository's releases (fine-grained, Contents: read). */
  token?: string
  /** `owner/name` of the repository the mobile app is released from. */
  repository?: string
  fetch?: typeof fetch
  /** How long the release list is reused. */
  ttlMs?: number
}

export interface AppReleaseService {
  /** Whether a token was configured; without it there's nothing to read from a private repository. */
  configured: boolean
  /** Newest Android release with an APK: stable ones only, or betas too. Throws when GitHub can't be read. */
  latestAndroid: (channel: AppChannel) => Promise<AndroidRelease | null>
  /** Short-lived URL to download the APK of a release, signed by GitHub. */
  apkUrl: (tag: string) => Promise<string | null>
}

/**
 * Reads the mobile app's GitHub releases on behalf of the app, so the token stays on the server:
 * the repository is private, and an APK can't carry a credential without leaking it.
 */
export function createAppReleaseService({ token, repository = 'roziscoding/maimoni', fetch: fetcher = fetch, ttlMs = 5 * 60_000 }: AppReleaseServiceOptions = {}): AppReleaseService {
  const api = `https://api.github.com/repos/${repository}`
  const headers = { 'Authorization': `Bearer ${token}`, 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'maimoni' }
  let cached: { releases: AndroidRelease[], expiresAt: number } | null = null

  async function androidReleases(): Promise<AndroidRelease[]> {
    if (cached && cached.expiresAt > Date.now())
      return cached.releases
    const response = await fetcher(`${api}/releases?per_page=100`, { headers: { ...headers, Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(10_000) })
    if (!response.ok)
      throw new Error(`GitHub releases: HTTP ${response.status}`)
    const releases = releasesSchema.parse(await response.json()).flatMap((release): AndroidRelease[] => {
      const version = appVersionFromTag(release.tag_name)
      const apk = release.assets.find(asset => asset.name.endsWith('.apk'))
      if (release.draft || !version || !apk)
        return []
      return [{
        tag: release.tag_name,
        version: version.version,
        versionCode: version.code,
        prerelease: release.prerelease,
        notes: release.body,
        publishedAt: release.published_at,
        apk: { id: apk.id, name: apk.name, sha256: apk.digest?.startsWith('sha256:') ? apk.digest.slice('sha256:'.length) : null },
      }]
    })
    cached = { releases, expiresAt: Date.now() + ttlMs }
    return releases
  }

  return {
    configured: Boolean(token),

    async latestAndroid(channel) {
      if (!token)
        return null
      try {
        const candidates = (await androidReleases()).filter(release => channel === 'beta' || !release.prerelease)
        return candidates.reduce<AndroidRelease | null>((newest, release) => !newest || release.versionCode > newest.versionCode ? release : newest, null)
      }
      catch (error) {
        log.withError(error).warn('could not read the app releases')
        throw error
      }
    },

    async apkUrl(tag) {
      if (!token)
        return null
      const release = (await androidReleases()).find(entry => entry.tag === tag)
      if (!release)
        return null
      // GitHub answers an asset download with a redirect to a signed, short-lived URL; hand that
      // to the client instead of streaming the APK through this server.
      const response = await fetcher(`${api}/releases/assets/${release.apk.id}`, {
        headers: { ...headers, Accept: 'application/octet-stream' },
        redirect: 'manual',
        signal: AbortSignal.timeout(10_000),
      })
      const location = response.headers.get('location')
      if (response.status < 300 || response.status >= 400 || !location)
        throw new Error(`GitHub asset ${release.apk.id}: HTTP ${response.status}`)
      return location
    },
  }
}
