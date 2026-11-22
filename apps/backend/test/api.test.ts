import type { Conversion, DailySpend, MonthDetail, MonthItem, MonthListEntry, TemplateDetail, TemplateItem, UserCurrency } from '@maimoni/shared'
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
    expect(body.summary.brl.net).toBe(9000)
    // The projection converts everything at the rate: no fee is taken off.
    expect(body.summary.transfer).toMatchObject({ projected: { sentBrl: 9000, eur: 1500 }, eur: 1500 })

    expect((await request('POST', '/months', { year: 2026, month: 10 })).status).toBe(409)
  })

  test('editing an amount confirms it and updates totals', async () => {
    await seedTemplate()
    const { body: created } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    const nubank = created.items.find(item => item.name === 'Nubank')!

    const { body: item } = await request<MonthItem>('PATCH', `/months/2026/10/items/${nubank.id}`, { amount: 2000, expression: '1500+500', paid: true })
    expect(item).toMatchObject({ amount: 2000, expression: '1500+500', paid: true, needsReview: false })

    const { body: month } = await request<MonthDetail>('GET', '/months/2026/10')
    expect(month.summary.brl.expenses).toBe(3000)
    expect(month.summary.brl.paid).toBe(2000)
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
    const { body } = await request<MonthDetail>('PATCH', '/months/2026/10', { exchangeRate: 5 })
    expect(body.month.exchangeRate).toBe(5)
    expect(body.summary.transfer.rate).toBe(5)

    const { body: unlocked } = await request<MonthDetail>('PATCH', '/months/2026/10', { exchangeRate: null })
    expect(unlocked.summary.transfer.rate).toBe(6)
  })

  test('creates, lists, updates and deletes completed conversions', async () => {
    await seedTemplate()
    const base = '/months/2026/10'
    const { body: month } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    expect(month.conversions).toEqual([])

    // Only what was sent and what arrived are given. At the rate of 6, 480 EUR are worth 2880 BRL,
    // so the other 120 BRL were the fee. A fee sent by an older client is ignored.
    const { status, body: created } = await request<Conversion>('POST', `${base}/conversions`, {
      day: 5,
      sentBrl: 3000,
      feeBrl: 999,
      receivedEur: 480,
      note: 'primeira parte',
    })
    expect(status).toBe(201)
    expect(created).toMatchObject({ day: 5, sentBrl: 3000, feeBrl: 120, receivedEur: 480, note: 'primeira parte' })

    const { body: converted } = await request<MonthDetail>('GET', base)
    expect(converted.conversions).toHaveLength(1)
    expect(converted.summary.transfer).toMatchObject({
      remainingBrl: 6000,
      realized: { sentBrl: 3000, convertedBrl: 2880, feeBrl: 120, receivedEur: 480 },
      projected: { sentBrl: 6000, eur: 1000 },
      eur: 1480,
    })
    expect((await request<Conversion[]>('GET', `${base}/conversions`)).body).toHaveLength(1)

    // New amounts get a new fee: 500 EUR are worth exactly the 3000 BRL sent.
    const { body: updated } = await request<Conversion>('PATCH', `${base}/conversions/${created.id}`, { receivedEur: 500, note: null })
    expect(updated).toMatchObject({ sentBrl: 3000, feeBrl: 0, receivedEur: 500, note: null })
    expect((await request<MonthDetail>('GET', base)).body.summary.transfer.eur).toBe(1500)

    // A fee is never negative, and the month's locked rate is the one used.
    await request('PATCH', base, { exchangeRate: 5 })
    const { body: locked } = await request<Conversion>('POST', `${base}/conversions`, { day: 6, sentBrl: 1000, receivedEur: 190 })
    expect(locked.feeBrl).toBe(50)
    const { body: cheap } = await request<Conversion>('POST', `${base}/conversions`, { day: 6, sentBrl: 1000, receivedEur: 250 })
    expect(cheap.feeBrl).toBe(0)
    // Changing the day or the note keeps the fee, even after the rate moved.
    await request('PATCH', base, { exchangeRate: 4 })
    expect((await request<Conversion>('PATCH', `${base}/conversions/${locked.id}`, { day: 7 })).body).toMatchObject({ day: 7, feeBrl: 50 })
    await request('DELETE', `${base}/conversions/${locked.id}`)
    await request('DELETE', `${base}/conversions/${cheap.id}`)

    expect((await request('DELETE', `${base}/conversions/${created.id}`)).status).toBe(204)
    expect((await request<MonthDetail>('GET', base)).body.conversions).toEqual([])
  })

  test('rejects invalid completed conversions', async () => {
    await request('POST', '/months', { year: 2026, month: 2 })
    const input = { sentBrl: 1000, receivedEur: 160 }
    expect((await request('POST', '/months/2026/2/conversions', { ...input, day: 29 })).status).toBe(400)
    expect((await request('POST', '/months/2026/2/conversions', { ...input, day: 1, sentBrl: 0 })).status).toBe(400)
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
    expect(body[0]!.summary.brl.net).toBe(9000)
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

  expect((await request('DELETE', '/data')).status).toBe(404)

  expect((await request<MonthListEntry[]>('GET', '/months')).body).toHaveLength(1)
})

test('clearing data wipes months and template', async () => {
  ({ request } = await setup(6, {}, { enablePurge: true }))
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

  test('the first currency added is the main one', async () => {
    expect((await request<UserCurrency[]>('GET', base)).body).toEqual([])

    const first = await request<UserCurrency>('POST', base, { currency: 'BRL', isMain: false })
    expect(first.status).toBe(201)
    expect(first.body).toEqual({ currency: 'BRL', isMain: true })
    expect((await request<UserCurrency>('POST', base, { currency: 'EUR' })).body).toEqual({ currency: 'EUR', isMain: false })

    expect((await request('POST', base, { currency: 'EUR' })).status).toBe(409)
    expect((await request('POST', base, { currency: 'USD' })).status).toBe(400)
    expect((await request<UserCurrency[]>('GET', base)).body).toEqual([{ currency: 'BRL', isMain: true }, { currency: 'EUR', isMain: false }])
  })

  test('a currency added as the main one demotes the previous one', async () => {
    await request('POST', base, { currency: 'BRL' })

    const added = await request<UserCurrency>('POST', base, { currency: 'EUR', isMain: true })
    expect(added.status).toBe(201)
    expect(added.body).toEqual({ currency: 'EUR', isMain: true })
    expect((await request<UserCurrency[]>('GET', base)).body).toEqual([{ currency: 'EUR', isMain: true }, { currency: 'BRL', isMain: false }])

    // One that is already there is refused without changing which one is main.
    expect((await request('POST', base, { currency: 'BRL', isMain: true })).status).toBe(409)
    expect((await request<UserCurrency[]>('GET', base)).body).toEqual([{ currency: 'EUR', isMain: true }, { currency: 'BRL', isMain: false }])
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
    expect((await request('PATCH', `${base}/EUR`, { isMain: true })).status).toBe(404)
    await request('POST', base, { currency: 'EUR' })

    const { body } = await request<UserCurrency[]>('PATCH', `${base}/EUR`, { isMain: true })
    expect(body).toEqual([{ currency: 'EUR', isMain: true }, { currency: 'BRL', isMain: false }])
    // Idempotent on the one that is already main.
    expect((await request<UserCurrency[]>('PATCH', `${base}/EUR`, { isMain: true })).body).toEqual(body)
    expect((await request('PATCH', `${base}/BRL`, { isMain: false })).status).toBe(400)
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
    expect((await request<UserCurrency[]>('GET', base)).body).toEqual([{ currency: 'EUR', isMain: true }])
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
    const net = opened.summary.eur.net
    expect(opened.summary.allowance).toMatchObject({ activeDay: 1, days: total, spentToday: 0 })

    const { status, body: spend } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 30, note: 'mercado' })
    expect(status).toBe(201)
    await request('POST', `${base}/spends`, { day: 1, amount: 12.5, expression: '10+2.5' })

    const { body: spent } = await request<MonthDetail>('GET', base)
    expect(spent.items).toHaveLength(5)
    expect(spent.spends.map(item => item.amount)).toEqual([30, 12.5])
    expect(spent.summary.eur.net).toBe(net)
    expect(spent.summary.allowance.eur).toBe(opened.summary.allowance.eur)
    expect(spent.summary.allowance.remainingEur).toBeCloseTo(opened.summary.allowance.eur! - 42.5, 2)

    const { body: closed } = await request<MonthDetail>('PATCH', base, { activeDay: 2 })
    expect(closed.summary.allowance).toMatchObject({ activeDay: 2, days: total - 1, spentBefore: 42.5, spentToday: 0 })
    expect(closed.summary.allowance.eur).toBeCloseTo((net - 42.5) / (total - 1), 1)

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
