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
}

export interface WiseService {
  /** Wise's own BRL→EUR quote, driven by the sent BRL or received EUR amount. */
  quote: (input: WiseQuoteQuery) => Promise<WiseQuote | null>
}

/** Uses Wise's public comparison API, which prices a transfer the same way the app does: mid-market rate, fee charged on the amount sent. */
export function createWiseService({ fetch: fetcher = fetch, ttlMs = 5 * 60_000 }: WiseServiceOptions = {}): WiseService {
  const cache = new Map<string, { quote: WiseQuote, expiresAt: number }>()

  return {
    async quote(input) {
      const field = input.sendAmount === undefined ? 'recipientGetsAmount' : 'sendAmount'
      const amount = Math.round((input.sendAmount ?? input.recipientGetsAmount!) * 100) / 100
      const key = `${field}:${amount}`
      const cached = cache.get(key)
      if (cached && cached.expiresAt > Date.now())
        return cached.quote

      try {
        const url = `https://api.wise.com/v4/comparisons/?${field}=${amount}&sourceCurrency=BRL&targetCurrency=EUR`
        const response = await fetcher(url, { signal: AbortSignal.timeout(5000) })
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
    },
  }
}
