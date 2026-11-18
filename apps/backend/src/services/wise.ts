import type { WiseQuote, WiseQuoteQuery } from '@maimoni/shared'
import { z } from 'zod'
import { log } from '../lib/log'

const comparisonSchema = z.object({
  providers: z.array(z.object({
    alias: z.string(),
    quotes: z.array(z.object({
      sendAmount: z.number().positive().optional(),
      rate: z.number().positive(),
      fee: z.number().nonnegative(),
      receivedAmount: z.number().nonnegative().nullable(),
    })),
  })),
})

export interface WiseServiceOptions {
  fetch?: typeof fetch
  /** How long a quote for a given amount is reused. */
  ttlMs?: number
  /** How many requests to Wise run at once; the rest wait for a free slot. */
  concurrency?: number
  /** How many requests may wait for a slot; beyond that a quote fails at once. */
  maxWaiting?: number
  /** How long a request to Wise may take, and how long a quote waits for a slot before giving up. */
  timeoutMs?: number
}

export interface WiseService {
  /** Wise's own BRL→EUR quote, driven by the sent BRL or received EUR amount. */
  quote: (input: WiseQuoteQuery) => Promise<WiseQuote | null>
}

/** Uses Wise's public comparison API, which prices a transfer the same way the app does: mid-market rate, fee charged on the amount sent. */
export function createWiseService({ fetch: fetcher = fetch, ttlMs = 5 * 60_000, concurrency = 4, maxWaiting = 100, timeoutMs = 5000 }: WiseServiceOptions = {}): WiseService {
  const cache = new Map<string, { quote: WiseQuote, expiresAt: number }>()
  /** Requests under way, by cache key, so the same amount is asked for once. */
  const pending = new Map<string, Promise<WiseQuote | null>>()
  let active = 0
  /** In arrival order; a Set, so a request that gives up leaves in constant time. */
  const waiting = new Set<() => void>()

  // The month list asks for one quote per month at once; without a limit, an account with many
  // months turns one request into as many requests to Wise.
  function acquire() {
    if (active < concurrency) {
      active++
      return Promise.resolve(true)
    }
    // A full line is refused at once: waiting requests cost memory and a timer each.
    if (waiting.size >= maxWaiting)
      return Promise.resolve(false)
    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        waiting.delete(grant)
        resolve(false)
      }, timeoutMs)
      function grant() {
        clearTimeout(timer)
        resolve(true)
      }
      waiting.add(grant)
    })
  }

  function release() {
    // A waiting request takes over the slot; otherwise it is freed.
    const [next] = waiting
    if (next) {
      waiting.delete(next)
      next()
    }
    else {
      active--
    }
  }

  async function request(input: WiseQuoteQuery, field: string, amount: number, key: string) {
    if (!await acquire()) {
      log.warn('Wise quote skipped, too many requests under way')
      return null
    }
    try {
      const url = `https://api.wise.com/v4/comparisons/?${field}=${amount}&sourceCurrency=BRL&targetCurrency=EUR`
      const response = await fetcher(url, { signal: AbortSignal.timeout(timeoutMs) })
      if (!response.ok)
        throw new Error(`HTTP ${response.status}`)
      const { providers } = comparisonSchema.parse(await response.json())
      const wise = providers.find(provider => provider.alias === 'wise')?.quotes[0]
      if (!wise)
        throw new Error('no Wise quote in response')
      const sendAmount = input.sendAmount ?? wise.sendAmount
      const receivedAmount = input.recipientGetsAmount ?? wise.receivedAmount
      if (sendAmount === undefined || receivedAmount === null)
        throw new Error('incomplete Wise quote')
      const quote: WiseQuote = { sendAmount, fee: wise.fee, receivedAmount, rate: wise.rate, fetchedAt: new Date().toISOString() }
      // Amounts change with every edit; keep the cache from growing without bound.
      if (cache.size >= 100)
        cache.clear()
      cache.set(key, { quote, expiresAt: Date.now() + ttlMs })
      return quote
    }
    catch (error) {
      log.withError(error).warn('Wise quote failed')
      return null
    }
    finally {
      release()
    }
  }

  return {
    quote(input) {
      const field = input.sendAmount === undefined ? 'recipientGetsAmount' : 'sendAmount'
      const amount = Math.round((input.sendAmount ?? input.recipientGetsAmount!) * 100) / 100
      const key = `${field}:${amount}`
      const cached = cache.get(key)
      if (cached && cached.expiresAt > Date.now())
        return Promise.resolve(cached.quote)
      let quote = pending.get(key)
      if (!quote) {
        quote = request(input, field, amount, key).finally(() => pending.delete(key))
        pending.set(key, quote)
      }
      return quote
    },
  }
}

/** A quote asked for by a user. `busy` when that user already has one under way. */
export type UserQuote = (userId: string, input: WiseQuoteQuery) => Promise<WiseQuote | null | 'busy'>

/** Lets each user ask for one quote at a time, so a single account can't fill the line every user's quotes wait in. */
export function onePerUser(wise: WiseService): UserQuote {
  const quoting = new Set<string>()
  return async (userId, input) => {
    if (quoting.has(userId))
      return 'busy'
    quoting.add(userId)
    try {
      return await wise.quote(input)
    }
    finally {
      quoting.delete(userId)
    }
  }
}
