import type { Database } from '../src/db'
import { expect, test } from 'bun:test'
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

test('falls back through providers, caches, then serves the stored rate when offline', async () => {
  const { db } = await setup()
  const online = fakeFetch({ 'api.frankfurter.dev': { rates: { BRL: 5.861 } } })
  const rates = createRateService({ db: db as unknown as Database, fetch: online.fetcher })

  const first = await rates.get()
  expect(first).toMatchObject({ rate: { rate: 5.861, source: 'frankfurter', stale: false }, error: null })
  await rates.get()
  expect(online.calls).toHaveLength(2) // wise failed, frankfurter answered, second call cached

  const offline = createRateService({ db: db as unknown as Database, fetch: fakeFetch({}).fetcher })
  expect(await offline.get()).toMatchObject({ rate: { rate: 5.861, source: 'cache', stale: true } })
})

test('reports every provider failure when nothing is available', async () => {
  const { db } = await setup()
  const rates = createRateService({ db: db as unknown as Database, fetch: fakeFetch({}).fetcher })
  expect(await rates.get()).toEqual({
    rate: null,
    error: 'Wise: offline: wise.com; Frankfurter (BCE): offline: api.frankfurter.dev; Open ER API: offline: open.er-api.com',
  })
})
