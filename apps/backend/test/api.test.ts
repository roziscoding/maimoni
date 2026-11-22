import type { DailySpend, MonthDetail, MonthItem, MonthListEntry, TemplateDetail, TemplateItem, UserCurrency } from '@maimoni/shared'
import { daysInMonth } from '@maimoni/shared'
import { beforeEach, describe, expect, test } from 'bun:test'
import { setup } from './setup'

let request: Awaited<ReturnType<typeof setup>>['request']

beforeEach(async () => {
  ({ request } = await setup())
})

async function seedTemplate() {
  await request('POST', '/template/items', { name: 'Salário', currency: 'BRL', kind: 'income', amount: 10000 })
  await request('POST', '/template/items', { name: 'Carro', currency: 'BRL', amount: 1000 })
  await request('POST', '/template/items', { name: 'Nubank', currency: 'BRL', variable: true })
  await request('POST', '/template/items', { name: 'Aluguel', currency: 'EUR', amount: 1000 })
  await request('POST', '/template/items', { name: 'Apple', currency: 'EUR', amount: 14.98, expression: '11.99+2.99' })
}

describe('template', () => {
  test('creates, lists, updates, reorders and deletes items', async () => {
    await seedTemplate()
    const { body: template } = await request<TemplateDetail>('GET', '/template')
    expect(template.items.map(item => item.name)).toEqual(['Salário', 'Carro', 'Nubank', 'Aluguel', 'Apple'])

    const apple = template.items.at(-1)!
    const { body: updated } = await request<TemplateItem>('PATCH', `/template/items/${apple.id}`, { amount: 15 })
    expect(updated.amount).toBe(15)
    expect(updated.expression).toBeNull()

    const ids = template.items.map(item => item.id).reverse()
    const { body: reordered } = await request<TemplateItem[]>('PUT', '/template/items/order', { ids })
    expect(reordered.map(item => item.id)).toEqual(ids)
    expect((await request('PUT', '/template/items/order', { ids: [apple.id, apple.id] })).status).toBe(400)

    expect((await request('DELETE', `/template/items/${apple.id}`)).status).toBe(204)
    expect((await request('DELETE', `/template/items/${apple.id}`)).status).toBe(404)
  })

  test('validates input', async () => {
    const { status, body } = await request('POST', '/template/items', { name: '', currency: 'USD' })
    expect(status).toBe(400)
    expect(body.issues).toBeArray()
  })
})

describe('months', () => {
  test('creates a month from the template and computes the summary', async () => {
    await seedTemplate()
    const { status, body } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    expect(status).toBe(201)
    expect(body.items).toHaveLength(5)

    const nubank = body.items.find(item => item.name === 'Nubank')!
    expect(nubank.amount).toBeNull()
    expect(nubank.needsReview).toBe(true)
    // The month is worked out in the user's main currency, and what is left in reais is converted
    // into it at the rate: no fee is taken off.
    expect(body.month).toMatchObject({ mainCurrency: 'EUR', lockedRates: {} })
    expect(body.summary.totals.BRL!.net).toBe(9000)
    expect(body.summary.conversions).toEqual([{ currency: 'BRL', rate: 6, rateLocked: false, net: 9000, converted: 1500 }])
    expect(body.summary.net).toBe(485.02)

    expect((await request('POST', '/months', { year: 2026, month: 10 })).status).toBe(409)
  })

  test('editing an amount confirms it and updates totals', async () => {
    await seedTemplate()
    const { body: created } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    const nubank = created.items.find(item => item.name === 'Nubank')!

    const { body: item } = await request<MonthItem>('PATCH', `/months/2026/10/items/${nubank.id}`, { amount: 2000, expression: '1500+500', paid: true })
    expect(item).toMatchObject({ amount: 2000, expression: '1500+500', paid: true, needsReview: false })

    const { body: month } = await request<MonthDetail>('GET', '/months/2026/10')
    expect(month.summary.totals.BRL!.expenses).toBe(3000)
    expect(month.summary.totals.BRL!.paid).toBe(2000)
  })

  test('partial updates keep the fields they do not send', async () => {
    await seedTemplate()
    const { body } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    const apple = body.items.find(item => item.name === 'Apple')!
    const { body: paid } = await request<MonthItem>('PATCH', `/months/2026/10/items/${apple.id}`, { paid: true })
    expect(paid).toMatchObject({ paid: true, amount: 14.98, expression: '11.99+2.99', kind: 'expense' })
    const { body: moved } = await request<MonthItem>('PATCH', `/months/2026/10/items/${apple.id}`, { kind: 'income' })
    expect(moved).toMatchObject({ kind: 'income', amount: 14.98, paid: true })

    const { body: template } = await request<TemplateDetail>('GET', '/template')
    const carro = template.items.find(item => item.name === 'Carro')!
    const { body: renamed } = await request<TemplateItem>('PATCH', `/template/items/${carro.id}`, { name: 'Carro novo' })
    expect(renamed).toMatchObject({ name: 'Carro novo', amount: 1000, kind: 'expense', variable: false })
  })

  test('locks and unlocks the exchange rate', async () => {
    await seedTemplate()
    await request('POST', '/months', { year: 2026, month: 10 })
    const { body } = await request<MonthDetail>('PATCH', '/months/2026/10', { lockedRates: { BRL: 5 } })
    expect(body.month.lockedRates).toEqual({ BRL: 5 })
    expect(body.summary.conversions[0]).toMatchObject({ currency: 'BRL', rate: 5, rateLocked: true, converted: 1800 })

    const { body: unlocked } = await request<MonthDetail>('PATCH', '/months/2026/10', { lockedRates: {} })
    expect(unlocked.summary.conversions[0]).toMatchObject({ rate: 6, rateLocked: false })
    expect((await request('PATCH', '/months/2026/10', { lockedRates: { BRL: 0 } })).status).toBe(400)
    expect((await request('PATCH', '/months/2026/10', { lockedRates: { USD: 5 } })).status).toBe(400)
  })

  test('a month keeps the main currency it was created with', async () => {
    await seedTemplate()
    await request('POST', '/months', { year: 2026, month: 10 })
    await request('PATCH', '/settings/currencies/BRL', { main: true })
    const { body: later } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 11 })

    // The new month is worked out in reais: the euros left (a deficit here) are converted into them.
    expect(later.month.mainCurrency).toBe('BRL')
    expect(later.rates).toMatchObject({ base: 'BRL', rates: { EUR: 6 } })
    expect(later.summary.conversions).toEqual([{ currency: 'EUR', rate: 6, rateLocked: false, net: -1014.98, converted: -169.16 }])
    expect(later.summary.net).toBe(8830.84)

    // The earlier one still is in euros, in the detail and in the list.
    const { body: earlier } = await request<MonthDetail>('GET', '/months/2026/10')
    expect(earlier.month.mainCurrency).toBe('EUR')
    expect(earlier.summary.net).toBe(485.02)
    const { body: list } = await request<MonthListEntry[]>('GET', '/months')
    expect(list.map(entry => [entry.month, entry.summary.main, entry.summary.net])).toEqual([[11, 'BRL', 8830.84], [10, 'EUR', 485.02]])

    // EUR is still what a month is worked out in, so it can be disabled but not removed.
    expect((await request('DELETE', '/settings/currencies/EUR')).status).toBe(409)
  })

  test('live rates are quoted against the main currency unless another base is asked for', async () => {
    expect((await request('GET', '/rates/live')).body).toMatchObject({ base: 'EUR', rates: { BRL: 6 } })
    expect((await request('GET', '/rates/live?base=BRL')).body).toMatchObject({ base: 'BRL', rates: { EUR: 6 } })
    expect((await request('GET', '/rates/live?base=USD')).status).toBe(400)
  })

  test('copies from the previous month', async () => {
    await seedTemplate()
    expect((await request('POST', '/months', { year: 2026, month: 9, source: 'previous' })).status).toBe(400)

    const { body: september } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 9 })
    await request('POST', '/months/2026/9/items', { name: 'Magalu', currency: 'BRL', amount: 650.49 })
    const nubank = september.items.find(item => item.name === 'Nubank')!
    await request('PATCH', `/months/2026/9/items/${nubank.id}`, { amount: 1200.5, paid: true })

    const { body: october } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10, source: 'previous' })
    expect(october.items).toHaveLength(6)
    const copied = october.items.find(item => item.name === 'Nubank')!
    expect(copied).toMatchObject({ amount: 1200.5, paid: false, needsReview: true })
    expect(october.items.find(item => item.name === 'Magalu')!.needsReview).toBe(false)
  })

  test('lists months newest first with summaries', async () => {
    await seedTemplate()
    await request('POST', '/months', { year: 2026, month: 3 })
    await request('POST', '/months', { year: 2026, month: 10 })
    await request('POST', '/months', { year: 2025, month: 12 })
    const { body } = await request<MonthListEntry[]>('GET', '/months')
    expect(body.map(month => `${month.year}-${month.month}`)).toEqual(['2026-10', '2026-3', '2025-12'])
    expect(body[0]!.summary.totals.BRL!.net).toBe(9000)
  })

  test('promotes a month item to the template', async () => {
    await seedTemplate()
    await request('POST', '/months', { year: 2026, month: 10 })
    const { body: extra } = await request<MonthItem>('POST', '/months/2026/10/items', { name: 'Academia', currency: 'EUR', amount: 35.99 })
    const { body: created } = await request<TemplateItem>('POST', `/months/2026/10/items/${extra.id}/promote`)
    expect(created).toMatchObject({ name: 'Academia', amount: 35.99, currency: 'EUR' })

    await request('PATCH', `/months/2026/10/items/${extra.id}`, { amount: 39.99 })
    const { body: updated } = await request<TemplateItem>('POST', `/months/2026/10/items/${extra.id}/promote`)
    expect(updated.id).toBe(created.id)
    expect(updated.amount).toBe(39.99)

    const { body: template } = await request<TemplateDetail>('GET', '/template')
    expect(template.items.at(-1)!.name).toBe('Academia')
  })

  test('deletes items and months', async () => {
    await seedTemplate()
    const { body } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    expect((await request('DELETE', `/months/2026/10/items/${body.items[0]!.id}`)).status).toBe(204)
    expect((await request('DELETE', '/months/2026/10')).status).toBe(204)
    expect((await request('GET', '/months/2026/10')).status).toBe(404)
  })

  test('validates params', async () => {
    expect((await request('GET', '/months/2026/13')).status).toBe(400)
  })
})

test('live rate endpoint reports unavailability', async () => {
  const { request } = await setup(null)
  const response = await request<{ error: string }>('GET', '/rates/live')
  expect(response.status).toBe(503)
  expect(response.body.error).toBe('Cotação indisponível no teste')
})

test('clearing data answers 404 unless purging is enabled', async () => {
  await request('POST', '/months', { year: 2026, month: 10 })

  expect((await request('GET', '/flags')).body).toEqual({ purge: false })
  expect((await request('DELETE', '/data')).status).toBe(404)

  expect((await request<MonthListEntry[]>('GET', '/months')).body).toHaveLength(1)
})

test('clearing data wipes months and template', async () => {
  ({ request } = await setup(6, {}, { enablePurge: true }))
  expect((await request('GET', '/flags')).body).toEqual({ purge: true })
  await seedTemplate()
  await request('POST', '/months', { year: 2026, month: 10 })

  expect((await request('DELETE', '/data')).status).toBe(204)

  expect((await request<MonthListEntry[]>('GET', '/months')).body).toEqual([])
  const { body: template } = await request<TemplateDetail>('GET', '/template')
  expect(template.items).toEqual([])
})

describe('currencies', () => {
  const base = '/settings/currencies'

  // These start from a user with no currencies.
  beforeEach(async () => {
    ({ request } = await setup(6, {}, { currencies: false }))
  })

  const entry = (currency: UserCurrency['currency'], main: boolean, enabled = true, inUse = false): UserCurrency => ({ currency, enabled, main, inUse })
  const list = async () => (await request<UserCurrency[]>('GET', base)).body

  test('the first currency added is the main one', async () => {
    expect(await list()).toEqual([])

    // It has to be enabled, since it is the main one.
    expect((await request('POST', base, { currency: 'BRL', enabled: false })).status).toBe(409)
    const first = await request<UserCurrency>('POST', base, { currency: 'BRL', main: false })
    expect(first.status).toBe(201)
    expect(first.body).toEqual(entry('BRL', true))
    expect((await request<UserCurrency>('POST', base, { currency: 'EUR' })).body).toEqual(entry('EUR', false))

    expect((await request('POST', base, { currency: 'EUR' })).status).toBe(409)
    expect((await request('POST', base, { currency: 'USD' })).status).toBe(400)
    expect(await list()).toEqual([entry('BRL', true), entry('EUR', false)])
  })

  test('a currency added as the main one demotes the previous one', async () => {
    await request('POST', base, { currency: 'BRL' })

    const added = await request<UserCurrency>('POST', base, { currency: 'EUR', main: true })
    expect(added.status).toBe(201)
    expect(added.body).toEqual(entry('EUR', true))
    expect(await list()).toEqual([entry('EUR', true), entry('BRL', false)])

    // One that is already there is refused without changing which one is main.
    expect((await request('POST', base, { currency: 'BRL', main: true })).status).toBe(409)
    expect(await list()).toEqual([entry('EUR', true), entry('BRL', false)])
  })

  test('a disabled currency can\'t be the main one', async () => {
    await request('POST', base, { currency: 'EUR' })
    expect((await request('POST', base, { currency: 'BRL', enabled: false, main: true })).status).toBe(400)
    expect((await request<UserCurrency>('POST', base, { currency: 'BRL', enabled: false })).body).toEqual(entry('BRL', false, false))

    expect((await request('PATCH', `${base}/BRL`, { enabled: false, main: true })).status).toBe(400)
    // Neither making the disabled one main nor disabling the main one goes through.
    expect((await request('PATCH', `${base}/BRL`, { main: true })).status).toBe(409)
    expect((await request('PATCH', `${base}/EUR`, { enabled: false })).status).toBe(409)
    expect(await list()).toEqual([entry('EUR', true), entry('BRL', false, false)])

    const { body } = await request<UserCurrency[]>('PATCH', `${base}/BRL`, { enabled: true, main: true })
    expect(body).toEqual([entry('BRL', true), entry('EUR', false)])
    expect((await request<UserCurrency[]>('PATCH', `${base}/EUR`, { enabled: false })).body).toEqual([entry('BRL', true), entry('EUR', false, false)])
  })

  test('a disabled currency still takes items and spends', async () => {
    await request('POST', base, { currency: 'EUR' })
    await request('POST', base, { currency: 'BRL', enabled: false })
    expect((await request('POST', '/template/items', { name: 'Carro', currency: 'BRL', amount: 1000 })).status).toBe(201)
  })

  test('items and spends are refused in a currency the user doesn\'t have', async () => {
    await request('POST', base, { currency: 'EUR' })
    await request('POST', '/months', { year: 2026, month: 10 })
    const { body: template } = await request<TemplateItem>('POST', '/template/items', { name: 'Aluguel', currency: 'EUR', amount: 1000 })
    const { body: item } = await request<MonthItem>('POST', '/months/2026/10/items', { name: 'Aluguel', currency: 'EUR', amount: 1000 })
    const { body: spend } = await request<DailySpend>('POST', '/months/2026/10/spends', { day: 1, amount: 10, currency: 'EUR' })

    const refused = [
      await request('POST', '/template/items', { name: 'Carro', currency: 'BRL', amount: 1000 }),
      await request('PATCH', `/template/items/${template.id}`, { currency: 'BRL' }),
      await request('POST', '/months/2026/10/items', { name: 'Carro', currency: 'BRL', amount: 1000 }),
      await request('PATCH', `/months/2026/10/items/${item.id}`, { currency: 'BRL' }),
      await request('POST', '/months/2026/10/spends', { day: 1, amount: 10, currency: 'BRL' }),
      await request('PATCH', `/months/2026/10/spends/${spend.id}`, { currency: 'BRL' }),
    ]
    expect(refused.map(response => response.status)).toEqual([400, 400, 400, 400, 400, 400])
    expect(refused[0]!.body).toEqual({ error: 'Currency is not one of the user\'s currencies' })

    await request('POST', base, { currency: 'BRL' })
    expect((await request('PATCH', `/template/items/${template.id}`, { currency: 'BRL' })).status).toBe(200)
    expect((await request('PATCH', `/months/2026/10/items/${item.id}`, { currency: 'BRL' })).status).toBe(200)
    expect((await request('PATCH', `/months/2026/10/spends/${spend.id}`, { currency: 'BRL' })).status).toBe(200)
  })

  test('making a currency the main one demotes the previous one', async () => {
    await request('POST', base, { currency: 'BRL' })
    expect((await request('PATCH', `${base}/EUR`, { main: true })).status).toBe(404)
    await request('POST', base, { currency: 'EUR' })

    const { body } = await request<UserCurrency[]>('PATCH', `${base}/EUR`, { main: true })
    expect(body).toEqual([entry('EUR', true), entry('BRL', false)])
    // Idempotent on the one that is already main.
    expect((await request<UserCurrency[]>('PATCH', `${base}/EUR`, { main: true })).body).toEqual(body)
    // `main: false` changes nothing on one that isn't main, and is refused on the main one: another has to take its place.
    expect((await request<UserCurrency[]>('PATCH', `${base}/BRL`, { main: false })).body).toEqual(body)
    expect((await request('PATCH', `${base}/EUR`, { main: false })).status).toBe(409)
    expect(await list()).toEqual(body)
  })

  test('replaces the whole list at once', async () => {
    const first = await request<UserCurrency[]>('PUT', base, { currencies: [{ currency: 'BRL', enabled: true }, { currency: 'EUR', enabled: true }], main: 'BRL' })
    expect(first.status).toBe(200)
    expect(first.body).toEqual([entry('BRL', true), entry('EUR', false)])

    // Swaps the main one and disables the other in one request.
    const swapped = await request<UserCurrency[]>('PUT', base, { currencies: [{ currency: 'BRL', enabled: false }, { currency: 'EUR', enabled: true }], main: 'EUR' })
    expect(swapped.body).toEqual([entry('EUR', true), entry('BRL', false, false)])

    // One left out is removed.
    expect((await request<UserCurrency[]>('PUT', base, { currencies: [{ currency: 'EUR', enabled: true }], main: 'EUR' })).body).toEqual([entry('EUR', true)])
    expect(await list()).toEqual([entry('EUR', true)])
  })

  test('refuses a list that leaves out a currency in use, or has a bad main', async () => {
    const both = [{ currency: 'BRL', enabled: true }, { currency: 'EUR', enabled: true }]
    await request('PUT', base, { currencies: both, main: 'EUR' })
    await request('POST', '/template/items', { name: 'Carro', currency: 'BRL', amount: 1000 })

    const invalid = [
      { currencies: [{ currency: 'EUR', enabled: true }], main: 'BRL' },
      { currencies: [{ currency: 'BRL', enabled: false }, { currency: 'EUR', enabled: true }], main: 'BRL' },
      { currencies: [...both, { currency: 'EUR', enabled: false }], main: 'EUR' },
      { currencies: [], main: 'EUR' },
      { currencies: [{ currency: 'USD', enabled: true }], main: 'USD' },
    ]
    for (const body of invalid)
      expect((await request('PUT', base, body)).status).toBe(400)

    // BRL has a template item, so it can be disabled but not left out. Nothing changes when it is refused.
    const refused = await request('PUT', base, { currencies: [{ currency: 'EUR', enabled: true }], main: 'EUR' })
    expect(refused.status).toBe(409)
    expect(refused.body.inUse).toEqual(['BRL'])
    expect(await list()).toEqual([entry('EUR', true), entry('BRL', false, true, true)])
    expect((await request<UserCurrency[]>('PUT', base, { currencies: [{ currency: 'BRL', enabled: false }, { currency: 'EUR', enabled: true }], main: 'EUR' })).body).toEqual([entry('EUR', true), entry('BRL', false, false, true)])
  })

  test('removes a currency unless it is the main one or in use', async () => {
    await request('POST', base, { currency: 'EUR' })
    await request('POST', base, { currency: 'BRL' })
    expect((await request('DELETE', `${base}/EUR`)).status).toBe(409)

    const { body: item } = await request<TemplateItem>('POST', '/template/items', { name: 'Carro', currency: 'BRL', amount: 1000 })
    expect((await request('DELETE', `${base}/BRL`)).status).toBe(409)
    await request('DELETE', `/template/items/${item.id}`)

    expect((await request('DELETE', `${base}/BRL`)).status).toBe(204)
    expect((await request('DELETE', `${base}/BRL`)).status).toBe(404)
    expect(await list()).toEqual([entry('EUR', true)])
  })
})

describe('daily spends', () => {
  // The current calendar month, with the open day pinned so the test doesn't depend on today's date.
  const now = new Date()
  const year = now.getFullYear()
  const month = now.getMonth() + 1
  const base = `/months/${year}/${month}`
  const total = daysInMonth(year, month)

  test('are kept apart from the month items and only touch the open day until it is closed', async () => {
    await seedTemplate()
    await request('POST', '/months', { year, month })
    const { body: opened } = await request<MonthDetail>('PATCH', base, { activeDay: 1 })
    const net = opened.summary.net!
    expect(opened.summary.allowance).toMatchObject({ activeDay: 1, days: total, spentToday: 0 })

    const { status, body: spend } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 30, note: 'mercado' })
    expect(status).toBe(201)
    await request('POST', `${base}/spends`, { day: 1, amount: 12.5, expression: '10+2.5' })

    const { body: spent } = await request<MonthDetail>('GET', base)
    expect(spent.items).toHaveLength(5)
    expect(spent.spends.map(item => item.amount)).toEqual([30, 12.5])
    // Sent without a currency, the spends went in the month's main one.
    expect(spent.spends.map(item => item.currency)).toEqual(['EUR', 'EUR'])
    expect(spent.summary.net).toBe(net)
    expect(spent.summary.allowance.amount).toBe(opened.summary.allowance.amount)
    expect(spent.summary.allowance.remaining).toBeCloseTo(opened.summary.allowance.amount! - 42.5, 2)

    const { body: closed } = await request<MonthDetail>('PATCH', base, { activeDay: 2 })
    expect(closed.summary.allowance).toMatchObject({ activeDay: 2, days: total - 1, spentBefore: 42.5, spentToday: 0 })
    expect(closed.summary.allowance.amount).toBeCloseTo((net - 42.5) / (total - 1), 1)

    const { body: edited } = await request<DailySpend>('PATCH', `${base}/spends/${spend.id}`, { amount: 25 })
    expect(edited).toMatchObject({ amount: 25, note: 'mercado', day: 1 })
    expect((await request('DELETE', `${base}/spends/${spend.id}`)).status).toBe(204)
    expect((await request<MonthDetail>('GET', base)).body.spends).toHaveLength(1)
  })

  test('take BRL, costing what the reais would have become at the rate', async () => {
    await seedTemplate()
    await request('POST', '/months', { year, month })
    await request('PATCH', base, { activeDay: 1 })
    const { body: euros } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 10 })
    expect(euros.currency).toBe('EUR')
    const { body: reais } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 120, currency: 'BRL' })
    expect(reais).toMatchObject({ currency: 'BRL', amount: 120 })

    const { body } = await request<MonthDetail>('GET', base)
    expect(body.summary.allowance.spentToday).toBe(10 + 120 / 6)
  })

  test('reject days outside the month', async () => {
    await request('POST', '/months', { year, month })
    expect((await request('POST', `${base}/spends`, { day: 31, amount: 1 })).status).toBe(total === 31 ? 201 : 400)
    expect((await request('POST', `${base}/spends`, { day: 0, amount: 1 })).status).toBe(400)
  })
})
