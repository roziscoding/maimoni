import type { Conversion, DailySpend, MonthDetail, MonthItem, MonthListEntry, TemplateDetail, TemplateItem } from '@maimoni/shared'
import { daysInMonth } from '@maimoni/shared'
import { beforeEach, describe, expect, test } from 'bun:test'
import { createApp } from '../src/app'
import { cookieHeaders, fakeWiseFee, login, setup, signIn } from './setup'

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
    expect(template.settings.wiseFee).toBe(0.039)

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

  test('updates settings', async () => {
    const { body } = await request('PATCH', '/settings', { wiseFee: 0.04 })
    expect(body.wiseFee).toBe(0.04)
  })
})

describe('months', () => {
  test('creates a month from the template and computes the summary', async () => {
    await seedTemplate()
    const { status, body } = await request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    expect(status).toBe(201)
    expect(body.items).toHaveLength(5)
    expect(body.month.wiseFee).toBeNull()

    const nubank = body.items.find(item => item.name === 'Nubank')!
    expect(nubank.amount).toBeNull()
    expect(nubank.needsReview).toBe(true)
    expect(body.summary.brl.net).toBe(9000)
    expect(body.summary.transfer).toMatchObject({ feeSource: 'wise', projected: { feeBrl: 360 } })
    expect(body.quote).toMatchObject({ sendAmount: 9000, fee: 360 })
    expect(body.summary.transfer.eur).toBeCloseTo((9000 * (1 - fakeWiseFee)) / 6, 2)

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

  test('manual fee overrides the Wise quote, and the settings fee covers Wise being down', async () => {
    await seedTemplate()
    await request('POST', '/months', { year: 2026, month: 10 })
    const { body: manual } = await request<MonthDetail>('PATCH', '/months/2026/10', { wiseFee: 0.039 })
    // The stored quote stays for when the manual fee is removed.
    expect(manual.quote).toMatchObject({ sendAmount: 9000 })
    expect(manual.summary.transfer).toMatchObject({ feeSource: 'manual', wiseFee: 0.039 })
    const { body: auto } = await request<MonthDetail>('PATCH', '/months/2026/10', { wiseFee: null })
    expect(auto.summary.transfer.feeSource).toBe('wise')

    const offline = await setup(6, false)
    await offline.request('POST', '/template/items', { name: 'Salário', currency: 'BRL', kind: 'income', amount: 1000 })
    const { body } = await offline.request<MonthDetail>('POST', '/months', { year: 2026, month: 10 })
    expect(body.fallbackFee).toBe(0.039)
    expect(body.summary.transfer).toMatchObject({ feeSource: 'fallback', projected: { feeBrl: 39 } })
    expect((await offline.request('GET', '/wise/quote?sendAmount=1000')).status).toBe(503)
    expect((await offline.request('POST', '/months/2026/10/quote')).status).toBe(503)
  })

  test('asks Wise when a month is created and when the user asks, never when it is read', async () => {
    const { db, app, auth } = await setup()
    const asked: number[] = []
    const counting = createApp({
      db: db as never,
      auth,
      rates: { get: async () => ({ rate: null, error: null }) },
      wise: {
        quote: async ({ sendAmount }) => {
          asked.push(sendAmount!)
          return { sendAmount: sendAmount!, fee: sendAmount! * 0.04, receivedAmount: 0, rate: 1 / 6, fetchedAt: new Date().toISOString() }
        },
      },
    })
    const headers = { ...cookieHeaders(await login(app, 'owner@example.com')), 'content-type': 'application/json' }
    const call = async (method: string, path: string, body?: unknown) => {
      const response = await counting.request(`/api${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) })
      const text = await response.text()
      return { status: response.status, body: (text ? JSON.parse(text) : null) as MonthDetail }
    }
    await call('POST', '/template/items', { name: 'Salário', currency: 'BRL', kind: 'income', amount: 1000 })
    const { body: created } = await call('POST', '/months', { year: 2026, month: 10 })
    expect(asked).toEqual([1000])
    expect(created.quote).toMatchObject({ sendAmount: 1000, fee: 40 })

    // Edits change the amount to send; the stored quote stays and its fee is applied in proportion.
    await call('POST', '/months/2026/10/items', { name: 'Bônus', currency: 'BRL', kind: 'income', amount: 1000 })
    const { body: edited } = await call('GET', '/months/2026/10')
    await call('GET', '/months')
    expect(asked).toEqual([1000])
    expect(edited.quote).toMatchObject({ sendAmount: 1000 })
    expect(edited.summary.transfer).toMatchObject({ feeSource: 'wise', projected: { sentBrl: 2000, feeBrl: 80 } })

    const { status, body: refreshed } = await call('POST', '/months/2026/10/quote')
    expect(status).toBe(200)
    expect(asked).toEqual([1000, 2000])
    expect(refreshed.quote).toMatchObject({ sendAmount: 2000 })
    expect((await call('GET', '/months/2026/10')).body.quote).toMatchObject({ sendAmount: 2000 })

    // Nothing to convert, nothing to ask.
    await call('POST', '/months', { year: 2026, month: 11 })
    const { body: empty } = await call('GET', '/months/2026/11')
    for (const item of empty.items)
      await call('DELETE', `/months/2026/11/items/${item.id}`)
    expect((await call('POST', '/months/2026/11/quote')).status).toBe(400)
    expect(asked).toEqual([1000, 2000, 1000])
  })

  test('quotes by BRL sent or EUR received', async () => {
    const { status, body } = await request('GET', '/wise/quote?sendAmount=10000')
    expect(status).toBe(200)
    expect(body).toMatchObject({ sendAmount: 10000, fee: 400 })
    const { body: reverse } = await request('GET', '/wise/quote?recipientGetsAmount=1000')
    expect(reverse).toMatchObject({ sendAmount: 6250, fee: 250, receivedAmount: 1000 })
    expect((await request('GET', '/wise/quote?sendAmount=-1')).status).toBe(400)
    expect((await request('GET', '/wise/quote?sendAmount=100&recipientGetsAmount=10')).status).toBe(400)
  })

  test('answers one quote at a time per user', async () => {
    const { db, app, auth } = await setup()
    // A Wise slow enough for two requests to overlap.
    const slow = createApp({
      db: db as never,
      auth,
      rates: { get: async () => ({ rate: null, error: null }) },
      wise: {
        quote: async () => {
          await Bun.sleep(50)
          return { sendAmount: 100, fee: 4, receivedAmount: 16, rate: 1 / 6, fetchedAt: new Date().toISOString() }
        },
      },
    })
    const quote = async (headers: Record<string, string>) => (await slow.request('/api/wise/quote?sendAmount=100', { headers })).status
    const owner = cookieHeaders(await login(app, 'owner@example.com'))
    const other = await signIn(app, auth, 'other@example.com')
    // The second user isn't held back by the first one's request.
    expect((await Promise.all([quote(owner), quote(owner), quote(other)])).toSorted()).toEqual([200, 200, 429])
    expect(await quote(owner)).toBe(200)
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

    const { status, body: created } = await request<Conversion>('POST', `${base}/conversions`, {
      day: 5,
      sentBrl: 3000,
      feeBrl: 120,
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
      projected: { sentBrl: 6000, feeBrl: 240, eur: 960 },
      eur: 1440,
    })
    expect((await request<Conversion[]>('GET', `${base}/conversions`)).body).toHaveLength(1)

    const { body: updated } = await request<Conversion>('PATCH', `${base}/conversions/${created.id}`, { receivedEur: 500, note: null })
    expect(updated).toMatchObject({ sentBrl: 3000, receivedEur: 500, note: null })
    expect((await request<MonthDetail>('GET', base)).body.summary.transfer.eur).toBe(1460)

    expect((await request('DELETE', `${base}/conversions/${created.id}`)).status).toBe(204)
    expect((await request<MonthDetail>('GET', base)).body.conversions).toEqual([])
  })

  test('rejects invalid completed conversions', async () => {
    await request('POST', '/months', { year: 2026, month: 2 })
    const input = { sentBrl: 1000, feeBrl: 40, receivedEur: 160 }
    expect((await request('POST', '/months/2026/2/conversions', { ...input, day: 29 })).status).toBe(400)
    expect((await request('POST', '/months/2026/2/conversions', { ...input, day: 1, feeBrl: 1001 })).status).toBe(400)
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

test('clearing data wipes months, template and settings', async () => {
  await seedTemplate()
  await request('POST', '/months', { year: 2026, month: 10 })
  await request('PATCH', '/settings', { wiseFee: 0.05 })

  expect((await request('DELETE', '/data')).status).toBe(204)

  expect((await request<MonthListEntry[]>('GET', '/months')).body).toEqual([])
  const { body: template } = await request<TemplateDetail>('GET', '/template')
  expect(template.items).toEqual([])
  expect(template.settings.wiseFee).toBe(0.039)
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

  test('take BRL, costing what the reais would have become through Wise', async () => {
    await seedTemplate()
    await request('POST', '/months', { year, month })
    await request('PATCH', base, { activeDay: 1 })
    const { body: euros } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 10 })
    expect(euros.currency).toBe('EUR')
    const { body: reais } = await request<DailySpend>('POST', `${base}/spends`, { day: 1, amount: 120, currency: 'BRL' })
    expect(reais).toMatchObject({ currency: 'BRL', amount: 120 })

    const { body } = await request<MonthDetail>('GET', base)
    expect(body.summary.allowance.spentToday).toBeCloseTo(10 + (120 * (1 - fakeWiseFee)) / 6, 2)
  })

  test('reject days outside the month', async () => {
    await request('POST', '/months', { year, month })
    expect((await request('POST', `${base}/spends`, { day: 31, amount: 1 })).status).toBe(total === 31 ? 201 : 400)
    expect((await request('POST', `${base}/spends`, { day: 0, amount: 1 })).status).toBe(400)
  })
})
