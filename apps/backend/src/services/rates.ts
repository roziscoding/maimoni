import type { LiveRate } from '@maimoni/shared'
import type { Database } from '../db'
import { and, desc, eq } from 'drizzle-orm'
import { z } from 'zod'
import { exchangeRates } from '../db/schema'
import { log } from '../lib/log'

interface Provider {
  source: Exclude<LiveRate['source'], 'cache'>
  label: string
  url: string
  parse: (body: unknown) => number
}

/** Tried in order. Wise first because it's the rate the transfer actually uses. */
const providers: Provider[] = [
  {
    source: 'wise',
    label: 'Wise',
    url: 'https://wise.com/rates/live?source=EUR&target=BRL',
    parse: body => z.object({ value: z.number().positive() }).parse(body).value,
  },
  {
    source: 'frankfurter',
    label: 'Frankfurter (BCE)',
    url: 'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=BRL',
    parse: body => z.object({ rates: z.object({ BRL: z.number().positive() }) }).parse(body).rates.BRL,
  },
  {
    source: 'open-er-api',
    label: 'Open ER API',
    url: 'https://open.er-api.com/v6/latest/EUR',
    parse: body => z.object({ rates: z.object({ BRL: z.number().positive() }) }).parse(body).rates.BRL,
  },
]

export interface RateServiceOptions {
  db: Database
  fetch?: typeof fetch
  /** How long a fetched rate is reused before asking the providers again. */
  ttlMs?: number
}

export interface RateService {
  /** Current EUR→BRL rate and, when providers failed, a readable reason. */
  get: () => Promise<RateResult>
}

export interface RateResult {
  rate: LiveRate | null
  error: string | null
}

export function createRateService({ db, fetch: fetcher = fetch, ttlMs = 5 * 60_000 }: RateServiceOptions): RateService {
  let cached: { result: RateResult, expiresAt: number } | null = null
  let pending: Promise<RateResult> | null = null

  async function fetchLive(): Promise<RateResult> {
    const failures: string[] = []
    for (const provider of providers) {
      try {
        const response = await fetcher(provider.url, { signal: AbortSignal.timeout(5000) })
        if (!response.ok)
          throw new Error(`HTTP ${response.status}`)
        const rate = provider.parse(await response.json())
        const [row] = await db.insert(exchangeRates)
          .values({ base: 'EUR', quote: 'BRL', rate, source: provider.source })
          .returning({ fetchedAt: exchangeRates.fetchedAt })
        return {
          rate: { base: 'EUR', quote: 'BRL', rate, source: provider.source, fetchedAt: new Date(row!.fetchedAt).toISOString(), stale: false },
          error: null,
        }
      }
      catch (error) {
        failures.push(`${provider.label}: ${error instanceof Error ? error.message : 'erro desconhecido'}`)
        log
          .withMetadata({ provider: provider.source })
          .withError(error)
          .warn('exchange rate provider failed')
      }
    }

    const [last] = await db.select().from(exchangeRates).where(and(eq(exchangeRates.base, 'EUR'), eq(exchangeRates.quote, 'BRL'))).orderBy(desc(exchangeRates.fetchedAt)).limit(1)
    const error = failures.join('; ')
    if (!last)
      return { rate: null, error }
    return {
      rate: { base: 'EUR', quote: 'BRL', rate: last.rate, source: 'cache', fetchedAt: new Date(last.fetchedAt).toISOString(), stale: true },
      error,
    }
  }

  return {
    async get() {
      if (cached && cached.expiresAt > Date.now())
        return cached.result
      pending ??= fetchLive().finally(() => {
        pending = null
      })
      const result = await pending
      // Stale fallbacks are retried sooner than fresh rates.
      if (result.rate)
        cached = { result, expiresAt: Date.now() + (result.rate.stale ? ttlMs / 5 : ttlMs) }
      return result
    },
  }
}
