import type { HonoLogLayerVariables } from '@loglayer/hono'
import type { Auth } from './auth'
import type { Database } from './db'
import type { AppReleaseService } from './services/app-releases'
import type { RateService } from './services/rates'
import type { WiseService } from './services/wise'
import { honoLogLayer } from '@loglayer/hono'
import { wiseQuoteQuerySchema } from '@maimoni/shared'
import { Hono } from 'hono'
import { HTTPException } from 'hono/http-exception'
import { requireSession } from './auth'
import { log } from './lib/log'
import { validate } from './lib/validate'
import { appReleaseRoutes } from './routes/app-releases'
import { conversionRoutes } from './routes/conversions'
import { dataRoutes } from './routes/data'
import { monthRoutes } from './routes/months'
import { spendRoutes } from './routes/spends'
import { templateRoutes } from './routes/template'
import { createAppReleaseService } from './services/app-releases'

const EXCLUDED_LOG_PATHS = [
  '/api/health',
]

export interface AppOptions {
  db: Database
  auth: Auth
  rates: RateService
  wise: WiseService
  /** Mobile app releases; without one, the update endpoints answer 503. */
  appReleases?: AppReleaseService
}

export function createApp({ db, auth, rates, wise, appReleases = createAppReleaseService() }: AppOptions) {
  // Public: health checks, Better Auth's own endpoints, and app updates (so a build without sign in can still update).
  const api = new Hono()
    .get('/health', c => c.json({ ok: true }))
    .on(['GET', 'POST'], '/auth/*', c => auth.handler(c.req.raw))
    .route('/', appReleaseRoutes(appReleases))
    .use(requireSession(auth))
    .get('/rates/live', async (c) => {
      const { rate, error } = await rates.get()
      if (!rate)
        return c.json({ error: error || 'Nenhuma cotação disponível' }, 503)
      return c.json(rate)
    })
    .get('/wise/quote', validate('query', wiseQuoteQuerySchema), async (c) => {
      const quote = await wise.quote(c.req.valid('query'))
      if (!quote)
        return c.json({ error: 'Wise quote unavailable' }, 503)
      return c.json(quote)
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
