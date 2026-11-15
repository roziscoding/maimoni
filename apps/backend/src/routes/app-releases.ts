import type { AppReleaseService } from '../services/app-releases'
import { Hono } from 'hono'
import { z } from 'zod'
import { validate } from '../lib/validate'

const channelQuery = z.object({ channel: z.enum(['stable', 'beta']).default('stable') })
const tagParam = z.object({ tag: z.string().regex(/^mobile-v[\w.-]+$/) })

/** What the Android app needs to offer an update: no GitHub access on its side. */
export function appReleaseRoutes(releases: AppReleaseService) {
  return new Hono()
    .get('/app/android/latest', validate('query', channelQuery), async (c) => {
      if (!releases.configured)
        return c.json({ error: 'App updates are not configured on this server' }, 503)
      let release
      try {
        release = await releases.latestAndroid(c.req.valid('query').channel)
      }
      catch {
        // Not a 404: the app would take it for "no newer release".
        return c.json({ error: 'Could not read the app releases from GitHub' }, 502)
      }
      if (!release)
        return c.json({ error: 'No release found' }, 404)
      return c.json({
        version: release.version,
        versionCode: release.versionCode,
        prerelease: release.prerelease,
        notes: release.notes,
        publishedAt: release.publishedAt,
        sha256: release.apk.sha256,
        url: `/api/app/android/releases/${release.tag}/apk`,
      })
    })
    .get('/app/android/releases/:tag/apk', validate('param', tagParam), async (c) => {
      const url = await releases.apkUrl(c.req.valid('param').tag)
      if (!url)
        return c.json({ error: 'Release not found' }, 404)
      return c.redirect(url, 302)
    })
}
