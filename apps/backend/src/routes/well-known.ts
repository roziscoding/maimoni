import type { AppLinks } from '../lib/app-links'
import { Hono } from 'hono'

/**
 * The files Android and iOS fetch from the domain before offering its passkeys to the app. They are
 * read at `/.well-known/*` on the public host, which the frontend forwards here.
 */
export function wellKnownRoutes({ android, appleAppId }: AppLinks) {
  return new Hono()
    .get('/well-known/assetlinks.json', (c) => {
      if (!android)
        return c.json({ error: 'Not found' }, 404)
      return c.json([{
        relation: ['delegate_permission/common.handle_all_urls', 'delegate_permission/common.get_login_creds'],
        target: { namespace: 'android_app', package_name: android.packageName, sha256_cert_fingerprints: android.fingerprints },
      }])
    })
    .get('/well-known/apple-app-site-association', (c) => {
      if (!appleAppId)
        return c.json({ error: 'Not found' }, 404)
      return c.json({ webcredentials: { apps: [appleAppId] } })
    })
}
