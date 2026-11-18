import { expect, test } from 'bun:test'
import { createWiseService } from '../src/services/wise'

const comparison = {
  amount: 10000,
  providers: [
    { alias: 'some-bank', quotes: [{ rate: 0.16, fee: 50, receivedAmount: 1592 }] },
    { alias: 'wise', quotes: [{ rate: 0.170484, fee: 399.72, receivedAmount: 1636.69, markup: 0, isConsideredMidMarketRate: true }] },
  ],
}

test('reads the Wise quote from the comparison API and caches it per amount', async () => {
  const urls: string[] = []
  const wise = createWiseService({
    fetch: (async (input: string | URL | Request) => {
      urls.push(String(input))
      return Response.json(comparison)
    }) as typeof fetch,
  })

  expect(await wise.quote({ sendAmount: 10000 })).toMatchObject({ sendAmount: 10000, fee: 399.72, receivedAmount: 1636.69, rate: 0.170484 })
  await wise.quote({ sendAmount: 10000 })
  expect(urls).toEqual(['https://api.wise.com/v4/comparisons/?sendAmount=10000&sourceCurrency=BRL&targetCurrency=EUR'])
})

test('returns null when Wise fails', async () => {
  const wise = createWiseService({ fetch: (async () => new Response('nope', { status: 502 })) as unknown as typeof fetch })
  expect(await wise.quote({ sendAmount: 10000 })).toBeNull()
})

test('asks Wise once for the same amount requested at the same time', async () => {
  let calls = 0
  const wise = createWiseService({
    fetch: (async () => {
      calls++
      await Bun.sleep(5)
      return Response.json(comparison)
    }) as unknown as typeof fetch,
  })
  const quotes = await Promise.all([wise.quote({ sendAmount: 10000 }), wise.quote({ sendAmount: 10000 }), wise.quote({ sendAmount: 10000 })])
  expect(quotes.every(quote => quote?.fee === 399.72)).toBe(true)
  expect(calls).toBe(1)
})

test('limits how many requests to Wise run at once', async () => {
  let running = 0
  let most = 0
  const wise = createWiseService({
    concurrency: 2,
    fetch: (async () => {
      most = Math.max(most, ++running)
      await Bun.sleep(5)
      running--
      return Response.json(comparison)
    }) as unknown as typeof fetch,
  })
  const quotes = await Promise.all(Array.from({ length: 10 }, (_, index) => wise.quote({ sendAmount: 100 + index })))
  expect(quotes.every(quote => quote !== null)).toBe(true)
  expect(most).toBe(2)
})

test('gives up on a quote that waits too long for a free slot', async () => {
  const wise = createWiseService({
    concurrency: 1,
    timeoutMs: 20,
    fetch: (async () => {
      await Bun.sleep(60)
      return Response.json(comparison)
    }) as unknown as typeof fetch,
  })
  const [first, second] = await Promise.all([wise.quote({ sendAmount: 100 }), wise.quote({ sendAmount: 200 })])
  expect(first).not.toBeNull()
  expect(second).toBeNull()
  // The slot is free again afterwards.
  expect(await wise.quote({ sendAmount: 300 })).not.toBeNull()
})
