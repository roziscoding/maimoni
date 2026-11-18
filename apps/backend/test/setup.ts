import type { Auth } from '../src/auth'
import type { Database } from '../src/db'
import type { Mail, MailService } from '../src/services/mail'
import type { RateService } from '../src/services/rates'
import { PGlite } from '@electric-sql/pglite'
import { drizzle } from 'drizzle-orm/pglite'
import { migrate } from 'drizzle-orm/pglite/migrator'
import { createApp } from '../src/app'
import { createAuth } from '../src/auth'
import { migrationsFolder } from '../src/db/migrate'
import * as schema from '../src/db/schema'

export const testPassword = 'correct horse battery staple'

/** Creates a user with a verified email and the test password, the way Better Auth's sign up would. */
export async function createTestUser(auth: Auth, email: string) {
  const ctx = await auth.$context
  const user = await ctx.internalAdapter.createUser({ email, name: email, emailVerified: true }, { method: 'email-password' })
  await ctx.internalAdapter.linkAccount({ userId: user.id, providerId: 'credential', accountId: user.id, password: await ctx.password.hash(testPassword) })
  return user
}

/** Signs an existing user in with email and password, returning the raw response. */
export async function login(app: ReturnType<typeof createApp>, email: string) {
  const response = await app.request('/api/auth/sign-in/email', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: testPassword }),
  })
  if (!response.ok)
    throw new Error(`sign in failed: ${response.status} ${await response.text()}`)
  return response
}

/** Session cookie from a sign in response, as request headers. */
export function cookieHeaders(response: Response) {
  return { cookie: response.headers.getSetCookie().map(value => value.split(';')[0]).join('; ') }
}

/** Creates a user and signs them in, returning headers that authenticate as them. */
export async function signIn(app: ReturnType<typeof createApp>, auth: Auth, email: string) {
  await createTestUser(auth, email)
  return cookieHeaders(await login(app, email))
}

/**
 * Fresh in-memory Postgres (PGlite) with migrations applied, plus the app wired to it. `rate` is the
 * live EUR→BRL rate (`null` for none), and `authEnv` sets auth environment variables.
 */
export async function setup(rate: number | null = 6, authEnv: Record<string, string> = {}) {
  const db = drizzle({ client: new PGlite(), schema })
  await migrate(db, { migrationsFolder })
  const rates: RateService = {
    get: async () => ({
      rate: rate === null ? null : { base: 'EUR', quote: 'BRL', rate, source: 'wise', fetchedAt: new Date().toISOString(), stale: false },
      error: rate === null ? 'Cotação indisponível no teste' : null,
    }),
  }
  /** Every email the app tried to send. */
  const mails: Mail[] = []
  const mail: MailService = {
    send: async (message) => {
      mails.push(message)
    },
  }
  const auth = createAuth({ db: db as unknown as Database, baseURL: 'http://localhost:3000', secret: 'test-secret-that-is-at-least-32-characters', mail, env: authEnv })
  const app = createApp({ db: db as unknown as Database, auth, rates })
  /** Request helper bound to a set of auth headers; `null` sends none. */
  const as = (auth: Record<string, string> | null) => async <T = any>(method: string, path: string, body?: unknown) => {
    const response = await app.request(`/api${path}`, {
      method,
      headers: { ...auth, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
    const text = await response.text()
    return { status: response.status, body: (text ? JSON.parse(text) : null) as T }
  }
  const request = as(await signIn(app, auth, 'owner@example.com'))
  return { db, app, auth, as, request, mails }
}
