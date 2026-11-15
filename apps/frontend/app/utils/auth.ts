import { createAuthClient } from 'better-auth/vue'

/** Talks to Better Auth at `/api/auth` on the page's own origin, which the Nuxt server proxies to the backend. */
export const authClient = createAuthClient()

export type AuthSession = typeof authClient.$Infer.Session

/** Where to go after sign in: the `redirect` query value when it is a path on this site, otherwise home. */
export function redirectTarget(value: unknown) {
  return typeof value === 'string' && value.startsWith('/') && !value.startsWith('//') && !value.startsWith('/login') ? value : '/'
}
