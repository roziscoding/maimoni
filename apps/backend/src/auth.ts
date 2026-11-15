import type { BetterAuthOptions } from 'better-auth'
import type { Database } from './db'
import process from 'node:process'
import { passkey } from '@better-auth/passkey'
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { bearer } from 'better-auth/plugins'
import { createMiddleware } from 'hono/factory'
import { schema } from './db'

export interface AuthOptions {
  db: Database
  /** Public URL the app is served from, e.g. `https://maimoni.example.com`. Defaults to `BETTER_AUTH_URL`. */
  baseURL?: string
  /** Signs cookies and tokens. Defaults to `BETTER_AUTH_SECRET`. */
  secret?: string
  /** Extra origins allowed to call the auth endpoints. Defaults to the comma-separated `BETTER_AUTH_TRUSTED_ORIGINS`. */
  trustedOrigins?: string[]
  env?: Record<string, string | undefined>
}

function list(value: string | undefined) {
  return value?.split(',').map(item => item.trim()).filter(Boolean) ?? []
}

/** Social providers whose credentials are present in the environment. */
function socialProviders(env: Record<string, string | undefined>, disableSignUp: boolean): BetterAuthOptions['socialProviders'] {
  const providers: NonNullable<BetterAuthOptions['socialProviders']> = {}
  if (env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET) {
    providers.google = {
      clientId: env.GOOGLE_CLIENT_ID,
      clientSecret: env.GOOGLE_CLIENT_SECRET,
      disableSignUp,
    }
  }
  if (env.APPLE_CLIENT_ID && env.APPLE_CLIENT_SECRET) {
    providers.apple = {
      clientId: env.APPLE_CLIENT_ID,
      clientSecret: env.APPLE_CLIENT_SECRET,
      // Native sign in on iOS sends an ID token issued to the bundle ID rather than the service ID.
      appBundleIdentifier: env.APPLE_APP_BUNDLE_IDENTIFIER || undefined,
      disableSignUp,
    }
  }
  return providers
}

/**
 * Sign up is disabled everywhere unless `AUTH_SIGNUP_ENABLED` is `true`; otherwise users are inserted
 * into the `user` table by hand. Google and Apple sign in link to an existing user with the same
 * email, as long as its `email_verified` is true.
 */
export function createAuth({ db, baseURL, secret, trustedOrigins, env = process.env }: AuthOptions) {
  const disableSignUp = env.AUTH_SIGNUP_ENABLED?.trim().toLowerCase() !== 'true'
  // compose.yaml passes unset optional variables as empty strings, hence `||`.
  const passkeyOrigin = baseURL || env.BETTER_AUTH_URL
  return betterAuth({
    baseURL: baseURL ?? env.BETTER_AUTH_URL,
    basePath: '/api/auth',
    secret: secret ?? env.BETTER_AUTH_SECRET,
    trustedOrigins: [...(trustedOrigins ?? list(env.BETTER_AUTH_TRUSTED_ORIGINS)), 'https://appleid.apple.com'],
    database: drizzleAdapter(db, { provider: 'pg', schema }),
    advanced: { database: { generateId: 'uuid' } },
    emailAndPassword: { enabled: true, disableSignUp },
    socialProviders: socialProviders(env, disableSignUp),
    account: { accountLinking: { enabled: true, trustedProviders: ['google', 'apple'] } },
    plugins: [
      passkey({
        rpName: 'maimoni',
        rpID: env.PASSKEY_RP_ID || (passkeyOrigin ? new URL(passkeyOrigin).hostname : undefined),
        origin: passkeyOrigin,
      }),
      // Lets the mobile app send `Authorization: Bearer <token>` instead of cookies.
      bearer(),
    ],
    telemetry: { enabled: false },
  })
}

export type Auth = ReturnType<typeof createAuth>
export type User = Auth['$Infer']['Session']['user']
export type Session = Auth['$Infer']['Session']['session']

export interface AuthEnv {
  Variables: {
    user: User
    session: Session
  }
}

/** Answers 401 without a valid session; otherwise exposes `user` and `session` on the context. */
export function requireSession(auth: Auth) {
  return createMiddleware<AuthEnv>(async (c, next) => {
    const result = await auth.api.getSession({ headers: c.req.raw.headers })
    if (!result)
      return c.json({ error: 'Unauthorized' }, 401)
    c.set('user', result.user)
    c.set('session', result.session)
    await next()
  })
}
