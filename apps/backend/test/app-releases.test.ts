import type { Auth } from '../src/auth'
import type { Database } from '../src/db'
import type { RateService } from '../src/services/rates'
import type { WiseService } from '../src/services/wise'
import { describe, expect, test } from 'bun:test'
import { createApp } from '../src/app'
import { createAppReleaseService } from '../src/services/app-releases'

function apk(id: number, name: string, digest?: string) {
  return { id, name, digest: digest ?? null }
}

function release(tag: string, prerelease: boolean, assets: ReturnType<typeof apk>[], draft = false) {
  return { tag_name: tag, draft, prerelease, body: `notes for ${tag}`, published_at: '2026-11-14T10:00:00Z', assets }
}

// Newest first, like the GitHub API; includes another app's release, a draft and one without APK.
const releases = [
  release('web-v3.0.0', false, []),
  release('mobile-v1.4.0-beta.1', true, [apk(41, 'maimoni-1.4.0-beta.1.apk', 'sha256:abc')]),
  release('mobile-v1.5.0-beta.1', true, [apk(51, 'maimoni-1.5.0-beta.1.apk')], true),
  release('mobile-v1.3.1', false, [apk(31, 'maimoni-1.3.1.apk', 'sha256:def'), apk(32, 'notes.txt')]),
  release('mobile-v1.3.2', false, []),
  release('mobile-v1.3.0', false, [apk(30, 'maimoni-1.3.0.apk')]),
]

function fakeGitHub() {
  const calls: string[] = []
  const fetcher = (async (input: string | URL | Request) => {
    const url = String(input)
    calls.push(url)
    if (url.endsWith('/releases?per_page=100'))
      return Response.json(releases)
    const asset = /\/releases\/assets\/(\d+)$/.exec(url)
    if (asset)
      return new Response(null, { status: 302, headers: { location: `https://objects.example/${asset[1]}?signed` } })
    return new Response('not found', { status: 404 })
  }) as typeof fetch
  return { calls, fetcher }
}

describe('createAppReleaseService', () => {
  test('picks the newest stable release with an APK, or the newest beta', async () => {
    const { fetcher } = fakeGitHub()
    const service = createAppReleaseService({ token: 'test', fetch: fetcher })

    expect(await service.latestAndroid('stable')).toMatchObject({ tag: 'mobile-v1.3.1', versionCode: 1030199, apk: { id: 31, sha256: 'def' } })
    expect(await service.latestAndroid('beta')).toMatchObject({ tag: 'mobile-v1.4.0-beta.1', versionCode: 1040001, prerelease: true, apk: { sha256: 'abc' } })
  })

  test('caches the release list and resolves the signed APK URL', async () => {
    const { calls, fetcher } = fakeGitHub()
    const service = createAppReleaseService({ token: 'test', repository: 'owner/repo', fetch: fetcher })

    await service.latestAndroid('stable')
    expect(await service.apkUrl('mobile-v1.3.0')).toBe('https://objects.example/30?signed')
    expect(await service.apkUrl('mobile-v9.9.9')).toBeNull()
    expect(calls).toEqual([
      'https://api.github.com/repos/owner/repo/releases?per_page=100',
      'https://api.github.com/repos/owner/repo/releases/assets/30',
    ])
  })

  test('without a token, reports nothing and calls nothing', async () => {
    const { calls, fetcher } = fakeGitHub()
    const service = createAppReleaseService({ fetch: fetcher })

    expect(service.configured).toBe(false)
    expect(await service.latestAndroid('beta')).toBeNull()
    expect(calls).toEqual([])
  })
})

describe('app update routes', () => {
  const app = createApp({
    db: {} as Database,
    auth: {} as Auth,
    rates: {} as RateService,
    wise: {} as WiseService,
    appReleases: createAppReleaseService({ token: 'test', fetch: fakeGitHub().fetcher }),
  })

  test('describes the latest release for the channel', async () => {
    const response = await app.request('/api/app/android/latest?channel=beta')
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({
      version: '1.4.0-beta.1',
      versionCode: 1040001,
      prerelease: true,
      notes: 'notes for mobile-v1.4.0-beta.1',
      publishedAt: '2026-11-14T10:00:00Z',
      sha256: 'abc',
      url: '/api/app/android/releases/mobile-v1.4.0-beta.1/apk',
    })
  })

  test('redirects the APK download to GitHub', async () => {
    const response = await app.request('/api/app/android/releases/mobile-v1.3.1/apk')
    expect(response.status).toBe(302)
    expect(response.headers.get('location')).toBe('https://objects.example/31?signed')
  })

  test('answers 502 when GitHub cannot be read', async () => {
    const failing = createApp({
      db: {} as Database,
      auth: {} as Auth,
      rates: {} as RateService,
      wise: {} as WiseService,
      appReleases: createAppReleaseService({ token: 'expired', fetch: (async () => new Response('Bad credentials', { status: 401 })) as typeof fetch }),
    })
    expect((await failing.request('/api/app/android/latest')).status).toBe(502)
  })

  test('answers 503 when the server has no token', async () => {
    const unconfigured = createApp({ db: {} as Database, auth: {} as Auth, rates: {} as RateService, wise: {} as WiseService })
    expect((await unconfigured.request('/api/app/android/latest')).status).toBe(503)
  })
})
