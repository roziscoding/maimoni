import type { Database } from '../src/db'
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

const frankfurter = (rate: number) => ({ 'api.frankfurter.dev': { rates: { BRL: rate } } })

test('asks the providers once a day and reads the stored rate the rest of it', async () => {
  const { db } = await setup()
  let now = new Date('2026-11-18T08:00:00Z')
  const service = (fetcher: typeof fetch) => createRateService({ db: db as unknown as Database, fetch: fetcher, now: () => now })

  const morning = fakeFetch(frankfurter(5.861))
  const rates = service(morning.fetcher)
  expect(await rates.get()).toMatchObject({ rate: { rate: 5.861, source: 'frankfurter', stale: false }, error: null })
  now = new Date('2026-11-18T23:00:00Z')
  await rates.get()
  expect(morning.calls).toHaveLength(1)

  // Another process, or this one after a restart, finds the day's rate in the database.
  const restarted = fakeFetch(frankfurter(9))
  expect(await service(restarted.fetcher).get()).toMatchObject({ rate: { rate: 5.861, source: 'frankfurter', stale: false } })
  expect(restarted.calls).toHaveLength(0)

  // The next day (UTC) asks again.
  now = new Date('2026-11-19T00:05:00Z')
  const nextDay = fakeFetch(frankfurter(5.9))
  expect(await service(nextDay.fetcher).get()).toMatchObject({ rate: { rate: 5.9, stale: false } })
  expect(nextDay.calls).toHaveLength(1)
  expect(await rates.get()).toMatchObject({ rate: { rate: 5.9 } })
  expect(morning.calls).toHaveLength(1)
})

test('falls back to the second provider, and to an earlier day when both are down', async () => {
  const { db } = await setup()
  let now = new Date('2026-11-18T08:00:00Z')
  const online = fakeFetch({ 'open.er-api.com': { rates: { BRL: 5.861 } } })
  expect(await createRateService({ db: db as unknown as Database, fetch: online.fetcher, now: () => now }).get())
    .toMatchObject({ rate: { rate: 5.861, source: 'open-er-api', stale: false }, error: null })
  expect(online.calls.map(url => new URL(url).hostname)).toEqual(['api.frankfurter.dev', 'open.er-api.com'])

  now = new Date('2026-11-19T08:00:00Z')
  const offline = fakeFetch({})
  const rates = createRateService({ db: db as unknown as Database, fetch: offline.fetcher, now: () => now })
  expect(await rates.get()).toMatchObject({ rate: { rate: 5.861, source: 'cache', stale: true } })
  // A failure isn't the day's answer: it is tried again, but not on every request.
  await rates.get()
  expect(offline.calls).toHaveLength(2)
  now = new Date('2026-11-19T08:06:00Z')
  await rates.get()
  expect(offline.calls).toHaveLength(4)
})

test('a rate stored today by a source that is no longer a provider is not used', async () => {
  const { db } = await setup()
  const now = new Date('2026-11-18T08:00:00Z')
  await db.insert(schema.exchangeRates).values({ base: 'EUR', quote: 'BRL', rate: 6.5, source: 'wise', fetchedAt: '2026-11-18T07:00:00Z' })
  const online = fakeFetch(frankfurter(5.861))
  expect(await createRateService({ db: db as unknown as Database, fetch: online.fetcher, now: () => now }).get())
    .toMatchObject({ rate: { rate: 5.861, source: 'frankfurter' } })
})

test('reports every provider failure when nothing is available', async () => {
  const { db } = await setup()
  const rates = createRateService({ db: db as unknown as Database, fetch: fakeFetch({}).fetcher })
  expect(await rates.get()).toEqual({
    rate: null,
    error: 'Frankfurter (BCE): offline: api.frankfurter.dev; Open ER API: offline: open.er-api.com',
  })
})
