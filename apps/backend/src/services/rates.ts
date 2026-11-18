import type { LiveRate } from '@maimoni/shared'
import type { Database } from '../db'
import { and, desc, eq, gte, inArray } from 'drizzle-orm'
import { z } from 'zod'
import { exchangeRates } from '../db/schema'
import { log } from '../lib/log'

interface Provider {
  source: Exclude<LiveRate['source'], 'cache'>
  label: string
  url: string
  parse: (body: unknown) => number
}

/**
 * Tried in order. Both publish reference rates once a day, with no key: Frankfurter the ECB's, on
 * working days, and Open ER API its own.
 */
const providers: Provider[] = [
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

/** How long to wait before asking the providers again after all of them failed. */
const RETRY_MS = 5 * 60_000

export interface RateServiceOptions {
  db: Database
  fetch?: typeof fetch
  /** The current time; tests move it to another day. */
  now?: () => Date
}

export interface RateService {
  /** Current EUR→BRL rate and, when providers failed, a readable reason. */
  get: () => Promise<RateResult>
}

export interface RateResult {
  rate: LiveRate | null
  error: string | null
}

/**
 * One rate a day. The providers publish once a day, so the first request of a day (UTC) asks them
 * and stores the answer in `exchange_rates`; every other request that day reads that row.
 */
export function createRateService({ db, fetch: fetcher = fetch, now = () => new Date() }: RateServiceOptions): RateService {
  /** The last answer, so most requests don't reach the database either. */
  let cached: { result: RateResult, day: string, retryAt: number | null } | null = null
  let pending: Promise<RateResult> | null = null

  const dayOf = (date: Date) => date.toISOString().slice(0, 10)

  /** Today's stored rate. A row from a source that is no longer a provider doesn't count. */
  async function stored(day: string): Promise<LiveRate | null> {
    const [row] = await db.select().from(exchangeRates).where(and(
      eq(exchangeRates.base, 'EUR'),
      eq(exchangeRates.quote, 'BRL'),
      gte(exchangeRates.fetchedAt, `${day}T00:00:00.000Z`),
      inArray(exchangeRates.source, providers.map(provider => provider.source)),
    )).orderBy(desc(exchangeRates.fetchedAt)).limit(1)
    if (!row)
      return null
    return { base: 'EUR', quote: 'BRL', rate: row.rate, source: row.source as Provider['source'], fetchedAt: new Date(row.fetchedAt).toISOString(), stale: false }
  }

  async function fetchLive(): Promise<RateResult> {
    const failures: string[] = []
    for (const provider of providers) {
      try {
        const response = await fetcher(provider.url, { signal: AbortSignal.timeout(5000) })
        if (!response.ok)
          throw new Error(`HTTP ${response.status}`)
        const rate = provider.parse(await response.json())
        const [row] = await db.insert(exchangeRates)
          .values({ base: 'EUR', quote: 'BRL', rate, source: provider.source, fetchedAt: now().toISOString() })
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

    // Every provider failed: an earlier day's rate is better than none.
    const [last] = await db.select().from(exchangeRates).where(and(eq(exchangeRates.base, 'EUR'), eq(exchangeRates.quote, 'BRL'))).orderBy(desc(exchangeRates.fetchedAt)).limit(1)
    const error = failures.join('; ')
    if (!last)
      return { rate: null, error }
    return {
      rate: { base: 'EUR', quote: 'BRL', rate: last.rate, source: 'cache', fetchedAt: new Date(last.fetchedAt).toISOString(), stale: true },
      error,
    }
  }

  async function today(day: string): Promise<RateResult> {
    const rate = await stored(day)
    return rate ? { rate, error: null } : fetchLive()
  }

  return {
    async get() {
      const day = dayOf(now())
      if (cached && cached.day === day && (cached.retryAt === null || cached.retryAt > now().getTime()))
        return cached.result
      pending ??= today(day).finally(() => {
        pending = null
      })
      const result = await pending
      // A day's rate is kept for the rest of the day; a failure is tried again after a while.
      const fresh = result.rate !== null && !result.rate.stale
      cached = { result, day, retryAt: fresh ? null : now().getTime() + RETRY_MS }
      return result
    },
  }
}
