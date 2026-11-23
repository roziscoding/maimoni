import type { MonthItem } from './schemas'
import { describe, expect, test } from 'bun:test'
import { evaluateExpression, isExpression } from './expression'
import { dayResults, nextActiveDay, openDay, remainingDays, spendInMain, summarizeMonth } from './summary'

let counter = 0
function item(partial: Partial<MonthItem> & Pick<MonthItem, 'currency' | 'amount'>): MonthItem {
  return {
    id: crypto.randomUUID(),
    monthId: crypto.randomUUID(),
    templateItemId: null,
    name: `item ${counter++}`,
    kind: 'expense',
    expression: null,
    paid: false,
    needsReview: false,
    position: counter,
    ...partial,
  }
}

// A made-up October: income in reais, bills in both currencies, worked out in euros.
const october = [
  item({ currency: 'BRL', kind: 'income', amount: 20000.5 }),
  ...[1250.99, 800, 2000, 0, 360, 1200.5, 3000, 650.49].map(amount => item({ currency: 'BRL', amount })),
  ...[50, 75.5, 90, 1000, 45, 7.99, 4.99, 20.99, 14.98, 60.55].map(amount => item({ currency: 'EUR', amount })),
]
const month = { year: 2026, month: 10, mainCurrency: 'EUR' as const, lockedRates: {}, activeDay: null }
/** Reais per euro. */
const context = { rates: { BRL: 5.868553 } }
const oct3 = new Date(2026, 9, 3)

describe('summarizeMonth', () => {
  test('computes the month totals in the main currency', () => {
    const summary = summarizeMonth(month, october, context, oct3)
    expect(summary.main).toBe('EUR')
    expect(summary.totals.BRL).toMatchObject({ expenses: 9261.98, net: 10738.52 })
    expect(summary.totals.EUR).toMatchObject({ income: 0, expenses: 1370, net: -1370 })
    // Everything left in reais is converted at the rate, with no fee: 10738.52 ÷ 5.868553.
    expect(summary.conversions).toEqual([{ currency: 'BRL', rate: 5.868553, rateLocked: false, net: 10738.52, converted: 1829.84 }])
    expect(summary.converted).toBe(1829.84)
    expect(summary.net).toBe(459.84)
    expect(summary.allowance.days).toBe(29)
    expect(summary.allowance.amount).toBeCloseTo(15.86, 2)
  })

  test('the same month worked out in the other currency', () => {
    // Euros per real.
    const summary = summarizeMonth({ ...month, mainCurrency: 'BRL' }, october, { rates: { EUR: 0.17 } }, oct3)
    expect(summary.main).toBe('BRL')
    // What is left in euros is a deficit, and it comes out of the reais: −1370 ÷ 0.17.
    expect(summary.conversions).toEqual([{ currency: 'EUR', rate: 0.17, rateLocked: false, net: -1370, converted: -8058.82 }])
    expect(summary.net).toBe(2679.7)
    expect(summary.allowance.amount).toBeCloseTo(2679.7 / 29, 2)
  })

  test('a single currency needs no rate', () => {
    const summary = summarizeMonth(month, october.filter(entry => entry.currency === 'EUR'), { rates: null }, oct3)
    expect(summary.totals).toEqual({ EUR: expect.objectContaining({ net: -1370 }) })
    expect(summary.conversions).toEqual([])
    expect(summary.net).toBe(-1370)
  })

  test('a locked rate overrides the live value, per currency', () => {
    const summary = summarizeMonth({ ...month, lockedRates: { BRL: 6 } }, october, context, oct3)
    expect(summary.rates).toEqual({ BRL: 6 })
    expect(summary.conversions[0]).toMatchObject({ rate: 6, rateLocked: true })
    expect(summary.conversions[0]!.converted).toBeCloseTo(10738.52 / 6, 2)
  })

  test('counts empty and review items as unresolved, splits paid/pending', () => {
    const summary = summarizeMonth(month, [
      item({ currency: 'BRL', amount: null }),
      item({ currency: 'BRL', amount: 10, paid: true }),
      item({ currency: 'BRL', amount: 5, needsReview: true }),
    ], { rates: { BRL: 5 } }, oct3)
    expect(summary.totals.BRL).toMatchObject({ unresolved: 2, paid: 10, pending: 5 })
    // The main currency is always there, even without items.
    expect(summary.totals.EUR).toMatchObject({ net: 0 })
  })

  test('no result or allowance without a rate, and no allowance for past months', () => {
    const missing = summarizeMonth(month, october, { rates: null }, oct3)
    expect(missing.conversions[0]).toMatchObject({ rate: null, converted: null })
    expect(missing).toMatchObject({ converted: null, net: null, allowance: { amount: null, remaining: null } })
    expect(summarizeMonth(month, october, context, new Date(2026, 10, 3)).allowance.amount).toBeNull()
  })

  test('a currency with nothing left doesn\'t wait for a rate', () => {
    const balanced = [item({ currency: 'BRL', kind: 'income', amount: 100 }), item({ currency: 'BRL', amount: 100 }), item({ currency: 'EUR', kind: 'income', amount: 50 })]
    expect(summarizeMonth(month, balanced, { rates: null }, oct3)).toMatchObject({ converted: 0, net: 50 })
  })
})

describe('daily allowance', () => {
  // Net 459.84 over 29 days (3rd to 31st) = 15.86 a day
  const base = summarizeMonth(month, october, context, oct3).allowance
  const eur = (day: number, amount: number) => ({ day, amount, currency: 'EUR' as const })

  test('spending on the open day only reduces that day', () => {
    const { allowance } = summarizeMonth(month, october, { ...context, spends: [eur(3, 20), eur(3, 5.5)] }, oct3)
    expect(allowance).toMatchObject({ activeDay: 3, days: 29, amount: base.amount, spentToday: 25.5, spentBefore: 0, spentTotal: 25.5 })
    expect(allowance.remaining).toBeCloseTo(base.amount! - 25.5, 2)
  })

  test('an unclosed day keeps its budget even after the calendar moves on', () => {
    const { allowance } = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends: [eur(3, 80)] }, new Date(2026, 9, 5))
    expect(allowance).toMatchObject({ activeDay: 3, days: 29, amount: base.amount })
    expect(allowance.remaining).toBeCloseTo(base.amount! - 80, 2)
  })

  test('closing spreads the leftover (or the overspend) over the remaining days', () => {
    const spends = [eur(3, 80)]
    const { allowance } = summarizeMonth({ ...month, activeDay: 5 }, october, { ...context, spends }, new Date(2026, 9, 5))
    expect(allowance).toMatchObject({ activeDay: 5, days: 27, spentBefore: 80, spentToday: 0 })
    expect(allowance.amount).toBeCloseTo((459.84 - 80) / 27, 1)
  })

  test('spends on a later day (left by undoing a close) still come out of the budget', () => {
    const { allowance } = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends: [eur(4, 29)] }, oct3)
    expect(allowance).toMatchObject({ spentBefore: 29, spentToday: 0 })
    expect(allowance.amount).toBeCloseTo((459.84 - 29) / 29, 1)
  })

  test('a spend in another currency costs what it would have become at the rate', () => {
    const inEur = 100 / 5.868553
    const summary = summarizeMonth(month, october, { ...context, spends: [{ day: 3, amount: 100, currency: 'BRL' }, eur(3, 10)] }, oct3)
    expect(summary.allowance.spentToday).toBeCloseTo(inEur + 10, 2)
    expect(spendInMain({ amount: 100, currency: 'BRL' }, summary)).toBeCloseTo(inEur, 2)
    expect(spendInMain({ amount: 100, currency: 'BRL' }, { main: 'EUR', rates: {} })).toBeNull()
    expect(spendInMain({ amount: 12.5, currency: 'EUR' }, { main: 'EUR', rates: {} })).toBe(12.5)
  })

  test('a currency only spends are in is converted too', () => {
    const euros = october.filter(entry => entry.currency === 'EUR')
    const summary = summarizeMonth(month, euros, { ...context, spends: [{ day: 3, amount: 100, currency: 'BRL' }] }, oct3)
    expect(summary.conversions).toEqual([{ currency: 'BRL', rate: 5.868553, rateLocked: false, net: 0, converted: 0 }])
    expect(summary.allowance.spentToday).toBe(17.04)
  })

  test('nextActiveDay jumps to today, or to tomorrow when today is the open day', () => {
    expect(nextActiveDay({ ...month, activeDay: 3 }, new Date(2026, 9, 5))).toBe(5)
    expect(nextActiveDay(month, oct3)).toBe(4)
    expect(nextActiveDay({ ...month, activeDay: 31 }, new Date(2026, 9, 31))).toBe(32)
    expect(openDay({ ...month, activeDay: 32 }, new Date(2026, 9, 31))).toBeNull()
    expect(nextActiveDay(month, new Date(2026, 10, 2))).toBeNull()
  })
})

describe('dayResults', () => {
  const eur = (day: number, amount: number) => ({ day, amount, currency: 'EUR' as const })
  const net = 459.84 // October's net (see 'computes the month totals in the main currency')

  test('replays closed days, matches the open day and projects upcoming ones', () => {
    const spends = [eur(1, 30), eur(2, 100), eur(3, 10)]
    const summary = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends }, oct3)
    const days = dayResults(month, summary, spends)
    expect(days).toHaveLength(31)

    const [first, second, third, fourth] = days
    expect(first).toMatchObject({ state: 'closed', spent: 30 })
    expect(first!.budget).toBeCloseTo(net / 31, 1)
    expect(first!.result).toBeCloseTo(net / 31 - 30, 1)
    expect(second!.budget).toBeCloseTo((net - 30) / 30, 1)
    expect(second!.result).toBeLessThan(0)

    expect(third).toMatchObject({ state: 'open', budget: summary.allowance.amount, spent: 10, result: summary.allowance.remaining })
    expect(fourth!.state).toBe('upcoming')
    expect(fourth!.budget).toBeCloseTo((net - 140) / 28, 1)
  })

  test('every day of a past month is closed', () => {
    const summary = summarizeMonth(month, october, { ...context, spends: [] }, new Date(2026, 10, 5))
    const days = dayResults(month, summary, [])
    expect(days.every(day => day.state === 'closed')).toBe(true)
    expect(days.at(-1)!.budget).toBeCloseTo(net, 1)
  })
})

describe('remainingDays', () => {
  test('current, past and future months', () => {
    expect(remainingDays(2026, 10, new Date(2026, 9, 31))).toBe(1)
    expect(remainingDays(2026, 9, new Date(2026, 9, 3))).toBe(0)
    expect(remainingDays(2027, 2, new Date(2026, 9, 3))).toBe(28)
  })
})

describe('evaluateExpression', () => {
  test('evaluates arithmetic', () => {
    expect(evaluateExpression('=11.99+2.99')).toBe(14.98)
    expect(evaluateExpression('20000.5 + 509.54')).toBe(20510.04)
    expect(evaluateExpression('(10 - 2) * 3 / 4')).toBe(6)
    expect(evaluateExpression('-1250,4')).toBe(-1250.4)
  })

  test('accepts pt-BR formatting and currency symbols', () => {
    expect(evaluateExpression('1.250,99')).toBe(1250.99)
    expect(evaluateExpression('R$ 20.000,50 + 509,54')).toBe(20510.04)
    expect(evaluateExpression('1.000.000')).toBe(1000000)
    expect(evaluateExpression('2.500')).toBe(2500)
    expect(evaluateExpression('1250.99')).toBe(1250.99)
    expect(evaluateExpression('10.5')).toBe(10.5)
    expect(evaluateExpression('€ 45')).toBe(45)
    expect(evaluateExpression('1,2,3')).toBeNull()
  })

  test('rejects garbage', () => {
    expect(evaluateExpression('abc')).toBeNull()
    expect(evaluateExpression('1+')).toBeNull()
    expect(evaluateExpression('')).toBeNull()
  })

  test('detects expressions', () => {
    expect(isExpression('11.99+2.99')).toBe(true)
    expect(isExpression('-12')).toBe(false)
    expect(isExpression('12.5')).toBe(false)
  })
})
