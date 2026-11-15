import type { BetterAuthOptions } from 'better-auth'
import type { Database } from './db'
import type { Mail, MailService } from './services/mail'
import process from 'node:process'
import { passkey } from '@better-auth/passkey'
import { betterAuth } from 'better-auth'
import { drizzleAdapter } from 'better-auth/adapters/drizzle'
import { bearer } from 'better-auth/plugins'
import { createMiddleware } from 'hono/factory'
import { schema } from './db'
import { appleClientSecret } from './lib/apple'
import { log } from './lib/log'
import { createMailService } from './services/mail'

export interface AuthOptions {
  db: Database
  /** Public URL the app is served from, e.g. `https://maimoni.example.com`. Defaults to `BETTER_AUTH_URL`. */
  baseURL?: string
  /** Signs cookies and tokens. Defaults to `BETTER_AUTH_SECRET`. */
  secret?: string
  /** Extra origins allowed to call the auth endpoints. Defaults to the comma-separated `BETTER_AUTH_TRUSTED_ORIGINS`. */
  trustedOrigins?: string[]
  /** Sends the password reset email. Defaults to Resend with `RESEND_API_KEY` and `RESEND_FROM`. */
  mail?: MailService
  env?: Record<string, string | undefined>
}

/** Frontend page the reset link lands on, with `?token=` or `?error=INVALID_TOKEN`. */
export const RESET_PASSWORD_PATH = '/reset-password'

const RESET_TOKEN_TTL_SECONDS = 60 * 60

function resetPasswordMail(to: string, url: string): Mail {
  return {
    to,
    subject: 'Redefinir sua senha do maimoni',
    text: [
      'Recebemos um pedido para redefinir a senha da sua conta no maimoni.',
      `Abra o link para escolher uma nova senha:\n${url}`,
      'O link vale por 1 hora. Se você não fez esse pedido, ignore este e-mail.',
    ].join('\n\n'),
    html: [
      '<p>Recebemos um pedido para redefinir a senha da sua conta no maimoni.</p>',
      `<p><a href="${url.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}">Escolher uma nova senha</a></p>`,
      '<p>O link vale por 1 hora. Se você não fez esse pedido, ignore este e-mail.</p>',
    ].join('\n'),
  }
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
  const { APPLE_CLIENT_ID: clientId, APPLE_TEAM_ID: teamId, APPLE_KEY_ID: keyId, APPLE_PRIVATE_KEY: privateKey } = env
  if (clientId && teamId && keyId && privateKey) {
    // Better Auth calls this once, when it starts. The secret lasts 180 days, so a process
    // that runs longer than that without a restart loses Apple sign in.
    providers.apple = async () => {
      const clientSecret = await appleClientSecret({ clientId, teamId, keyId, privateKey }).catch((error) => {
        log.withError(error).error('APPLE_PRIVATE_KEY could not sign a client secret, Apple sign in is off')
        return null
      })
      return {
        enabled: clientSecret !== null,
        clientId,
        clientSecret: clientSecret ?? '',
        // Native sign in on iOS sends an ID token issued to the bundle ID rather than the service ID.
        appBundleIdentifier: env.APPLE_APP_BUNDLE_IDENTIFIER || undefined,
        disableSignUp,
      }
    }
  }
  return providers
}

/**
 * Sign up is disabled everywhere unless `AUTH_SIGNUP_ENABLED` is `true`; otherwise users are inserted
 * into the `user` table by hand. Google and Apple sign in link to an existing user with the same
 * email, as long as its `email_verified` is true.
 */
export function createAuth({ db, baseURL, secret, trustedOrigins, mail, env = process.env }: AuthOptions) {
  const mailer = mail ?? createMailService({ apiKey: env.RESEND_API_KEY, from: env.RESEND_FROM })
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
    emailAndPassword: {
      enabled: true,
      disableSignUp,
      resetPasswordTokenExpiresIn: RESET_TOKEN_TTL_SECONDS,
      revokeSessionsOnPasswordReset: true,
      // Not awaited: waiting for Resend would make requests for existing emails slower than for unknown ones.
      sendResetPassword: async ({ user, url }) => {
        void mailer.send(resetPasswordMail(user.email, url))
      },
    },
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
