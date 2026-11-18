import type { HonoLogLayerVariables } from '@loglayer/hono'
import type { Auth } from './auth'
import type { Database } from './db'
import type { AppLinks } from './lib/app-links'
import type { AppReleaseService } from './services/app-releases'
import type { RateService } from './services/rates'
import type { WiseService } from './services/wise'
import { honoLogLayer } from '@loglayer/hono'
import { passwordResetRequestSchema, wiseQuoteQuerySchema } from '@maimoni/shared'
import { Hono } from 'hono'
import { HTTPException } from 'hono/http-exception'
import { requireSession, RESET_PASSWORD_PATH } from './auth'
import { appLinksFromEnv } from './lib/app-links'
import { log } from './lib/log'
import { validate } from './lib/validate'
import { appReleaseRoutes } from './routes/app-releases'
import { conversionRoutes } from './routes/conversions'
import { dataRoutes } from './routes/data'
import { monthRoutes } from './routes/months'
import { spendRoutes } from './routes/spends'
import { templateRoutes } from './routes/template'
import { wellKnownRoutes } from './routes/well-known'
import { createAppReleaseService } from './services/app-releases'

const EXCLUDED_LOG_PATHS = [
  '/api/health',
  // The emailed reset link: its path ends in the reset token, which stays valid until it is used.
  /^\/api\/auth\/reset-password\/./,
]

export interface AppOptions {
  db: Database
  auth: Auth
  rates: RateService
  wise: WiseService
  /** Mobile app releases; without one, the update endpoints answer 503. */
  appReleases?: AppReleaseService
  /** Mobile app identifiers for the `.well-known` files; without them those answer 404. */
  appLinks?: AppLinks
}

export function createApp({ db, auth, rates, wise, appReleases = createAppReleaseService(), appLinks = appLinksFromEnv() }: AppOptions) {
  /** Users with a `/wise/quote` request under way. */
  const quoting = new Set<string>()
  // Public: health checks, Better Auth's own endpoints, the sign in provider list, password reset requests, app updates (so a build without sign in can still update), and the app association files.
  const api = new Hono()
    .get('/health', c => c.json({ ok: true }))
    .on(['GET', 'POST'], '/auth/*', c => auth.handler(c.req.raw))
    // Lets the sign in page offer only the providers whose credentials are set.
    .get('/sign-in-providers', async c => c.json((await auth.$context).socialProviders.map(provider => provider.id)))
    // Answers 204 whether or not the email belongs to a user, so it can't be used to find out who has an account.
    // Goes through Better Auth's handler rather than `auth.api` to keep its rate limit and origin check.
    .post('/password-reset', validate('json', passwordResetRequestSchema), (c) => {
      const headers = new Headers(c.req.raw.headers)
      headers.delete('content-length')
      // Not awaited: Better Auth reads the database for an unknown email and writes to it for a
      // known one, and the difference in time would tell the two apart.
      void auth.handler(new Request(new URL('/api/auth/request-password-reset', c.req.url), {
        method: 'POST',
        headers,
        body: JSON.stringify({ email: c.req.valid('json').email, redirectTo: RESET_PASSWORD_PATH }),
      })).then((response) => {
        if (!response.ok)
          log.withMetadata({ status: response.status }).warn('password reset request refused')
      }, error => log.withError(error).error('password reset request failed'))
      return c.body(null, 204)
    })
    .route('/', appReleaseRoutes(appReleases))
    .route('/', wellKnownRoutes(appLinks))
    .use(requireSession(auth))
    .get('/rates/live', async (c) => {
      const { rate, error } = await rates.get()
      if (!rate)
        return c.json({ error: error || 'Nenhuma cotação disponível' }, 503)
      return c.json(rate)
    })
    .get('/wise/quote', validate('query', wiseQuoteQuerySchema), async (c) => {
      // One at a time per user, so a single account can't fill the line every user's quotes wait in.
      const userId = c.var.user.id
      if (quoting.has(userId))
        return c.json({ error: 'Another quote is under way' }, 429)
      quoting.add(userId)
      try {
        const quote = await wise.quote(c.req.valid('query'))
        if (!quote)
          return c.json({ error: 'Wise quote unavailable' }, 503)
        return c.json(quote)
      }
      finally {
        quoting.delete(userId)
      }
    })
    .route('/', templateRoutes(db))
    .route('/', monthRoutes(db, rates, wise))
    .route('/', conversionRoutes(db))
    .route('/', spendRoutes(db))
    .route('/', dataRoutes(db))

  const app = new Hono<{ Variables: HonoLogLayerVariables }>()

  app.use(honoLogLayer({
    instance: log,
    group: true,
    autoLogging: {
      ignore: EXCLUDED_LOG_PATHS,
    },
  }))

  return app
    .route('/api', api)
    .notFound(c => c.json({ error: 'Not found' }, 404))
    .onError((error, c) => {
      if (error instanceof HTTPException)
        return c.json({ error: error.message }, error.status)
      c.var.logger.withError(error).error('request failed')
      return c.json({ error: 'Internal server error' }, 500)
    })
}

export type App = ReturnType<typeof createApp>
