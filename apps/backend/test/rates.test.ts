import type { Currency } from '@maimoni/shared'
import type { Database } from '../src/db'
import { currencies } from '@maimoni/shared'
import { expect, test } from 'bun:test'
import * as schema from '../src/db/schema'
import { createRateService } from '../src/services/rates'
import { setup } from './setup'

function fakeFetch(responses: Record<string, unknown>) {
  const calls: string[] = []
  const fetcher = (async (input: string | URL | Request) => {
    const url = String(input)
    calls.push(url)
    const host = new URL(url).hostname
    if (!(host in responses))
      throw new Error(`offline: ${host}`)
    return Response.json(responses[host])
  }) as typeof fetch
  return { fetcher, calls }
}

/** A provider's answer: every currency at 1, except the ones given. */
const answer = (rates: Partial<Record<Currency, number>>) => ({ rates: { ...Object.fromEntries(currencies.map(currency => [currency, 1])), ...rates } })
const frankfurter = (rates: Partial<Record<Currency, number>>) => ({ 'api.frankfurter.dev': answer(rates) })
const others = (base: Currency) => currencies.filter(currency => currency !== base)

test('asks the providers once a day and reads the stored rates the rest of it', async () => {
  const { db } = await setup()
  let now = new Date('2026-11-18T08:00:00Z')
  const service = (fetcher: typeof fetch) => createRateService({ db: db as unknown as Database, fetch: fetcher, now: () => now })

  const morning = fakeFetch(frankfurter({ BRL: 5.861, USD: 1.08 }))
  const rates = service(morning.fetcher)
  const first = await rates.get('EUR')
  expect(first).toMatchObject({ rates: { base: 'EUR', rates: { BRL: 5.861, USD: 1.08 }, source: 'frankfurter', stale: false }, error: null })
  // Every other currency is quoted, and the base isn't.
  expect(Object.keys(first.rates!.rates).sort()).toEqual(others('EUR'))
  now = new Date('2026-11-18T23:00:00Z')
  await rates.get('EUR')
  expect(morning.calls).toHaveLength(1)

  // Another process, or this one after a restart, finds the day's rates in the database.
  const restarted = fakeFetch(frankfurter({ BRL: 9 }))
  expect(await service(restarted.fetcher).get('EUR')).toMatchObject({ rates: { rates: { BRL: 5.861, USD: 1.08 }, source: 'frankfurter', stale: false } })
  expect(restarted.calls).toHaveLength(0)

  // The next day (UTC) asks again.
  now = new Date('2026-11-19T00:05:00Z')
  const nextDay = fakeFetch(frankfurter({ BRL: 5.9 }))
  expect(await service(nextDay.fetcher).get('EUR')).toMatchObject({ rates: { rates: { BRL: 5.9 }, stale: false } })
  expect(nextDay.calls).toHaveLength(1)
  expect(await rates.get('EUR')).toMatchObject({ rates: { rates: { BRL: 5.9 } } })
  expect(morning.calls).toHaveLength(1)
})

test('each base currency is asked for and stored on its own', async () => {
  const { db } = await setup()
  const now = new Date('2026-11-18T08:00:00Z')
  const online = fakeFetch(frankfurter({ BRL: 5.861, EUR: 0.1706 }))
  const rates = createRateService({ db: db as unknown as Database, fetch: online.fetcher, now: () => now })

  expect(await rates.get('EUR')).toMatchObject({ rates: { base: 'EUR', rates: { BRL: 5.861 } } })
  expect(await rates.get('BRL')).toMatchObject({ rates: { base: 'BRL', rates: { EUR: 0.1706 } } })
  expect(online.calls).toEqual([
    `https://api.frankfurter.dev/v1/latest?base=EUR&symbols=${others('EUR').join(',')}`,
    `https://api.frankfurter.dev/v1/latest?base=BRL&symbols=${others('BRL').join(',')}`,
  ])
  await rates.get('BRL')
  expect(online.calls).toHaveLength(2)
})

test('a rate far below one keeps its digits', async () => {
  const { db } = await setup()
  const now = new Date('2026-11-18T08:00:00Z')
  const service = (fetcher: typeof fetch) => createRateService({ db: db as unknown as Database, fetch: fetcher, now: () => now })
  // One rupiah in euros.
  await service(fakeFetch(frankfurter({ EUR: 0.0000551234 })).fetcher).get('IDR')
  // Read back from the database by a service with nothing cached.
  expect((await service(fakeFetch({}).fetcher).get('IDR')).rates?.rates.EUR).toBe(0.0000551234)
})

test('falls back to the second provider, and to an earlier day when both are down', async () => {
  const { db } = await setup()
  let now = new Date('2026-11-18T08:00:00Z')
  const online = fakeFetch({ 'open.er-api.com': answer({ BRL: 5.861 }) })
  expect(await createRateService({ db: db as unknown as Database, fetch: online.fetcher, now: () => now }).get('EUR'))
    .toMatchObject({ rates: { rates: { BRL: 5.861 }, source: 'open-er-api', stale: false }, error: null })
  expect(online.calls.map(url => new URL(url).hostname)).toEqual(['api.frankfurter.dev', 'open.er-api.com'])

  now = new Date('2026-11-19T08:00:00Z')
  const offline = fakeFetch({})
  const rates = createRateService({ db: db as unknown as Database, fetch: offline.fetcher, now: () => now })
  expect(await rates.get('EUR')).toMatchObject({ rates: { rates: { BRL: 5.861 }, source: 'cache', stale: true } })
  // A failure isn't the day's answer: it is tried again, but not on every request.
  await rates.get('EUR')
  expect(offline.calls).toHaveLength(2)
  now = new Date('2026-11-19T08:06:00Z')
  await rates.get('EUR')
  expect(offline.calls).toHaveLength(4)
})

test('a provider that leaves a currency out is passed over', async () => {
  const { db } = await setup()
  const online = fakeFetch({ 'api.frankfurter.dev': { rates: { BRL: 5.9 } }, 'open.er-api.com': answer({ BRL: 5.861 }) })
  expect(await createRateService({ db: db as unknown as Database, fetch: online.fetcher }).get('EUR'))
    .toMatchObject({ rates: { rates: { BRL: 5.861 }, source: 'open-er-api' } })
})

test('rates stored today by a source that is no longer a provider are not used', async () => {
  const { db } = await setup()
  const now = new Date('2026-11-18T08:00:00Z')
  await db.insert(schema.exchangeRates).values({ base: 'EUR', quote: 'BRL', rate: 6.5, source: 'wise', fetchedAt: '2026-11-18T07:00:00Z' })
  const online = fakeFetch(frankfurter({ BRL: 5.861 }))
  expect(await createRateService({ db: db as unknown as Database, fetch: online.fetcher, now: () => now }).get('EUR'))
    .toMatchObject({ rates: { rates: { BRL: 5.861 }, source: 'frankfurter' } })
})

test('reports every provider failure when nothing is available', async () => {
  const { db } = await setup()
  const rates = createRateService({ db: db as unknown as Database, fetch: fakeFetch({}).fetcher })
  expect(await rates.get('EUR')).toEqual({
    rates: null,
    error: 'Frankfurter (BCE): offline: api.frankfurter.dev; Open ER API: offline: open.er-api.com',
  })
})
