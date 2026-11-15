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
