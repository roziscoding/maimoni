import type { Currency, LiveRates, Rates } from '@maimoni/shared'
import type { Database } from '../db'
import { currencies } from '@maimoni/shared'
import { and, desc, eq, gte, inArray } from 'drizzle-orm'
import { z } from 'zod'
import { exchangeRates } from '../db/schema'
import { log } from '../lib/log'

interface Provider {
  source: Exclude<LiveRates['source'], 'cache'>
  label: string
  url: (base: Currency, quotes: Currency[]) => string
}

/**
 * Tried in order. Both publish reference rates once a day, with no key: Frankfurter the ECB's, on
 * working days, and Open ER API its own. Both answer `{ rates: { <currency>: <units per one base> } }`.
 */
const providers: Provider[] = [
  {
    source: 'frankfurter',
    label: 'Frankfurter (BCE)',
    url: (base, quotes) => `https://api.frankfurter.dev/v1/latest?base=${base}&symbols=${quotes.join(',')}`,
  },
  {
    source: 'open-er-api',
    label: 'Open ER API',
    url: base => `https://open.er-api.com/v6/latest/${base}`,
  },
]

const answerSchema = z.object({ rates: z.record(z.string(), z.number()) })

/** How long to wait before asking the providers again after all of them failed. */
const RETRY_MS = 5 * 60_000

export interface RateServiceOptions {
  db: Database
  fetch?: typeof fetch
  /** The current time; tests move it to another day. */
  now?: () => Date
}

export interface RateService {
  /** Current rates of every other currency against `base` and, when providers failed, a readable reason. */
  get: (base: Currency) => Promise<RateResult>
}

export interface RateResult {
  rates: LiveRates | null
  error: string | null
}

/**
 * One set of rates a day for each base currency asked for. The providers publish once a day, so
 * the first request of a day (UTC) asks them and stores the answer in `exchange_rates`, one row
 * per quoted currency; every other request that day reads those rows.
 */
export function createRateService({ db, fetch: fetcher = fetch, now = () => new Date() }: RateServiceOptions): RateService {
  /** The last answer per base, so most requests don't reach the database either. */
  const cached = new Map<Currency, { result: RateResult, day: string, retryAt: number | null }>()
  const pending = new Map<Currency, Promise<RateResult>>()

  const dayOf = (date: Date) => date.toISOString().slice(0, 10)
  const quotesOf = (base: Currency) => currencies.filter(currency => currency !== base)

  /** The newest stored row of each quoted currency, optionally only today's from a current provider. */
  async function latest(base: Currency, today?: string) {
    return db.selectDistinctOn([exchangeRates.quote]).from(exchangeRates).where(and(
      eq(exchangeRates.base, base),
      today ? gte(exchangeRates.fetchedAt, `${today}T00:00:00.000Z`) : undefined,
      // A row from a source that is no longer a provider doesn't count as today's answer.
      today ? inArray(exchangeRates.source, providers.map(provider => provider.source)) : undefined,
    )).orderBy(exchangeRates.quote, desc(exchangeRates.fetchedAt))
  }

  function toRates(rows: Awaited<ReturnType<typeof latest>>): Rates {
    return Object.fromEntries(rows.map(row => [row.quote, row.rate]))
  }

  /** Today's stored rates, when they cover every quoted currency. */
  async function stored(base: Currency, day: string): Promise<LiveRates | null> {
    const rows = await latest(base, day)
    const quotes = quotesOf(base)
    const newest = rows.toSorted((a, b) => b.fetchedAt.localeCompare(a.fetchedAt))[0]
    if (!newest || !quotes.every(quote => rows.some(row => row.quote === quote)))
      return null
    return { base, rates: toRates(rows), source: newest.source as Provider['source'], fetchedAt: new Date(newest.fetchedAt).toISOString(), stale: false }
  }

  async function fetchLive(base: Currency): Promise<RateResult> {
    const quotes = quotesOf(base)
    const failures: string[] = []
    for (const provider of providers) {
      try {
        const response = await fetcher(provider.url(base, quotes), { signal: AbortSignal.timeout(5000) })
        if (!response.ok)
          throw new Error(`HTTP ${response.status}`)
        const answer = answerSchema.parse(await response.json()).rates
        const rates: Rates = {}
        for (const quote of quotes) {
          const rate = answer[quote]
          if (!rate || rate <= 0)
            throw new Error(`no rate for ${quote}`)
          rates[quote] = rate
        }
        const fetchedAt = now().toISOString()
        await db.insert(exchangeRates).values(quotes.map(quote => ({ base, quote, rate: rates[quote]!, source: provider.source, fetchedAt })))
        return { rates: { base, rates, source: provider.source, fetchedAt, stale: false }, error: null }
      }
      catch (error) {
        failures.push(`${provider.label}: ${error instanceof Error ? error.message : 'erro desconhecido'}`)
        log
          .withMetadata({ provider: provider.source, base })
          .withError(error)
          .warn('exchange rate provider failed')
      }
    }

    // Every provider failed: an earlier day's rates are better than none.
    const rows = await latest(base)
    const error = failures.join('; ')
    const newest = rows.toSorted((a, b) => b.fetchedAt.localeCompare(a.fetchedAt))[0]
    if (!newest)
      return { rates: null, error }
    return { rates: { base, rates: toRates(rows), source: 'cache', fetchedAt: new Date(newest.fetchedAt).toISOString(), stale: true }, error }
  }

  async function today(base: Currency, day: string): Promise<RateResult> {
    // With a single currency there is nothing to quote, and no one to ask.
    if (!quotesOf(base).length)
      return { rates: { base, rates: {}, source: 'cache', fetchedAt: now().toISOString(), stale: false }, error: null }
    const rates = await stored(base, day)
    return rates ? { rates, error: null } : fetchLive(base)
  }

  return {
    async get(base) {
      const day = dayOf(now())
      const last = cached.get(base)
      if (last && last.day === day && (last.retryAt === null || last.retryAt > now().getTime()))
        return last.result
      let request = pending.get(base)
      if (!request) {
        request = today(base, day).finally(() => pending.delete(base))
        pending.set(base, request)
      }
      const result = await request
      // A day's rates are kept for the rest of the day; a failure is tried again after a while.
      const fresh = result.rates !== null && !result.rates.stale
      cached.set(base, { result, day, retryAt: fresh ? null : now().getTime() + RETRY_MS })
      return result
    },
  }
}
