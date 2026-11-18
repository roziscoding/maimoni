import type { Auth } from '../src/auth'
import type { Database } from '../src/db'
import type { AppLinks } from '../src/lib/app-links'
import type { RateService } from '../src/services/rates'
import { afterEach, describe, expect, mock, spyOn, test } from 'bun:test'
import { createApp } from '../src/app'
import { androidOrigin, appLinksFromEnv, passkeyOrigins } from '../src/lib/app-links'
import { log } from '../src/lib/log'

const FINGERPRINT = 'FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C'
const OTHER = '14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5'

afterEach(() => {
  mock.restore()
})

describe('androidOrigin', () => {
  test('hashes the fingerprint the way Android reports it', () => {
    expect(androidOrigin(FINGERPRINT)).toBe('android:apk-key-hash:-sYXRdwJA3hvue3mKpYrOZ9zSPC7b4mbgzJmdZEDO5w')
  })
})

describe('appLinksFromEnv', () => {
  test('keeps every fingerprint, in uppercase', () => {
    const links = appLinksFromEnv({ ANDROID_APP_PACKAGE: 'ninja.roz.maimoni', ANDROID_APP_CERT_SHA256: `${FINGERPRINT}, ${OTHER.toLowerCase()}` })
    expect(links.android).toEqual({ packageName: 'ninja.roz.maimoni', fingerprints: [FINGERPRINT, OTHER] })
  })

  test('drops a value that is not a fingerprint and logs it', () => {
    const error = mock()
    const withMetadata = spyOn(log, 'withMetadata').mockReturnValue({ error })
    const links = appLinksFromEnv({ ANDROID_APP_PACKAGE: 'ninja.roz.maimoni', ANDROID_APP_CERT_SHA256: `${FINGERPRINT},FA:C6:17` })
    expect(links.android?.fingerprints).toEqual([FINGERPRINT])
    expect(withMetadata).toHaveBeenCalledWith({ value: 'FA:C6:17' })
    expect(error).toHaveBeenCalledTimes(1)
  })

  test('has no Android app without both the package and a fingerprint', () => {
    expect(appLinksFromEnv({ ANDROID_APP_PACKAGE: 'ninja.roz.maimoni' }).android).toBeUndefined()
    expect(appLinksFromEnv({ ANDROID_APP_CERT_SHA256: FINGERPRINT }).android).toBeUndefined()
    expect(appLinksFromEnv({ ANDROID_APP_PACKAGE: '', ANDROID_APP_CERT_SHA256: '' }).android).toBeUndefined()
  })

  test('joins the Apple team and bundle IDs', () => {
    expect(appLinksFromEnv({ APPLE_TEAM_ID: 'T', APPLE_APP_BUNDLE_IDENTIFIER: 'b.c' }).appleAppId).toBe('T.b.c')
    expect(appLinksFromEnv({ APPLE_TEAM_ID: 'T' }).appleAppId).toBeUndefined()
    expect(appLinksFromEnv({ APPLE_APP_BUNDLE_IDENTIFIER: 'b.c' }).appleAppId).toBeUndefined()
  })
})

describe('passkeyOrigins', () => {
  test('lists the Android origins after the web origin', () => {
    const links: AppLinks = { android: { packageName: 'ninja.roz.maimoni', fingerprints: [FINGERPRINT] } }
    expect(passkeyOrigins('http://localhost:3000', links)).toEqual(['http://localhost:3000', 'android:apk-key-hash:-sYXRdwJA3hvue3mKpYrOZ9zSPC7b4mbgzJmdZEDO5w'])
  })

  test('is the web origin alone without fingerprints', () => {
    expect(passkeyOrigins('http://localhost:3000', {})).toBe('http://localhost:3000')
    expect(passkeyOrigins(undefined, {})).toBeUndefined()
  })
})

function app(appLinks: AppLinks) {
  return createApp({ db: {} as Database, auth: {} as Auth, rates: {} as RateService, appLinks })
}

describe('well-known routes', () => {
  test('serves the Digital Asset Links statement', async () => {
    const response = await app({ android: { packageName: 'ninja.roz.maimoni', fingerprints: [FINGERPRINT, OTHER] } }).request('/api/well-known/assetlinks.json')
    expect(response.status).toBe(200)
    expect(response.headers.get('content-type')).toStartWith('application/json')
    expect(await response.json()).toEqual([{
      relation: ['delegate_permission/common.handle_all_urls', 'delegate_permission/common.get_login_creds'],
      target: { namespace: 'android_app', package_name: 'ninja.roz.maimoni', sha256_cert_fingerprints: [FINGERPRINT, OTHER] },
    }])
  })

  test('answers 404 for assetlinks.json without an Android app', async () => {
    const response = await app({}).request('/api/well-known/assetlinks.json')
    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: expect.any(String) })
  })

  test('serves the Apple app site association', async () => {
    const response = await app({ appleAppId: 'T.b.c' }).request('/api/well-known/apple-app-site-association')
    expect(response.status).toBe(200)
    expect(response.headers.get('content-type')).toStartWith('application/json')
    expect(await response.json()).toEqual({ webcredentials: { apps: ['T.b.c'] } })
  })

  test('answers 404 for apple-app-site-association without an Apple app', async () => {
    const response = await app({}).request('/api/well-known/apple-app-site-association')
    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: expect.any(String) })
  })
})
