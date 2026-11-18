import type { MonthItem } from './schemas'
import { describe, expect, test } from 'bun:test'
import { evaluateExpression, isExpression } from './expression'
import { conversionFee, dayResults, nextActiveDay, openDay, remainingDays, spendInEur, summarizeMonth } from './summary'

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

// A made-up October
const october = [
  item({ currency: 'BRL', kind: 'income', amount: 20000.5 }),
  ...[1250.99, 800, 2000, 0, 360, 1200.5, 3000, 650.49].map(amount => item({ currency: 'BRL', amount })),
  ...[50, 75.5, 90, 1000, 45, 7.99, 4.99, 20.99, 14.98, 60.55].map(amount => item({ currency: 'EUR', amount })),
]
const month = { year: 2026, month: 10, exchangeRate: null, activeDay: null }

describe('summarizeMonth', () => {
  test('computes the month totals', () => {
    const summary = summarizeMonth(month, october, { rate: 5.868553 }, new Date(2026, 9, 3))
    expect(summary.brl.expenses).toBe(9261.98)
    expect(summary.brl.net).toBe(10738.52)
    // Everything left is converted at the rate, with no fee: 10738.52 ÷ 5.868553.
    expect(summary.transfer.eur).toBeCloseTo(1829.84, 2)
    expect(summary.eur.expenses).toBe(1370)
    expect(summary.eur.net).toBeCloseTo(459.84, 2)
    expect(summary.allowance.days).toBe(29)
    expect(summary.allowance.eur).toBeCloseTo(15.86, 2)
    expect(summary.allowance.brl).toBeCloseTo(93.06, 1)
  })

  test('locked rate overrides the live value', () => {
    const summary = summarizeMonth({ ...month, exchangeRate: 6 }, october, { rate: 5.868553 }, new Date(2026, 9, 3))
    expect(summary.transfer.rate).toBe(6)
    expect(summary.transfer.rateLocked).toBe(true)
    expect(summary.transfer.projected.eur).toBeCloseTo(10738.52 / 6, 2)
    expect(summary.transfer.eur).toBe(summary.transfer.projected.eur)
  })

  test('counts empty and review items as unresolved, splits paid/pending', () => {
    const summary = summarizeMonth(month, [
      item({ currency: 'BRL', amount: null }),
      item({ currency: 'BRL', amount: 10, paid: true }),
      item({ currency: 'BRL', amount: 5, needsReview: true }),
    ], { rate: 5 }, new Date(2026, 9, 3))
    expect(summary.brl.unresolved).toBe(2)
    expect(summary.brl.paid).toBe(10)
    expect(summary.brl.pending).toBe(5)
  })

  test('no allowance without a rate or for past months', () => {
    expect(summarizeMonth(month, october, { rate: null }, new Date(2026, 9, 3)).allowance.eur).toBeNull()
    expect(summarizeMonth(month, october, { rate: 5.8 }, new Date(2026, 10, 3)).allowance.eur).toBeNull()
  })
})

describe('daily allowance', () => {
  const context = { rate: 5.868553 }
  const oct3 = new Date(2026, 9, 3)
  // EUR net 459.84 over 29 days (3rd to 31st) = 15.86 a day
  const base = summarizeMonth(month, october, context, oct3).allowance
  const eur = (day: number, amount: number) => ({ day, amount, currency: 'EUR' as const })

  test('spending on the open day only reduces that day', () => {
    const { allowance } = summarizeMonth(month, october, { ...context, spends: [eur(3, 20), eur(3, 5.5)] }, oct3)
    expect(allowance).toMatchObject({ activeDay: 3, days: 29, eur: base.eur, spentToday: 25.5, spentBefore: 0, spentTotal: 25.5 })
    expect(allowance.remainingEur).toBeCloseTo(base.eur! - 25.5, 2)
  })

  test('an unclosed day keeps its budget even after the calendar moves on', () => {
    const { allowance } = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends: [eur(3, 80)] }, new Date(2026, 9, 5))
    expect(allowance).toMatchObject({ activeDay: 3, days: 29, eur: base.eur })
    expect(allowance.remainingEur).toBeCloseTo(base.eur! - 80, 2)
  })

  test('closing spreads the leftover (or the overspend) over the remaining days', () => {
    const spends = [eur(3, 80)]
    const { allowance } = summarizeMonth({ ...month, activeDay: 5 }, october, { ...context, spends }, new Date(2026, 9, 5))
    expect(allowance).toMatchObject({ activeDay: 5, days: 27, spentBefore: 80, spentToday: 0 })
    expect(allowance.eur).toBeCloseTo((459.84 - 80) / 27, 1)
  })

  test('spends on a later day (left by undoing a close) still come out of the budget', () => {
    const { allowance } = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends: [eur(4, 29)] }, oct3)
    expect(allowance).toMatchObject({ spentBefore: 29, spentToday: 0 })
    expect(allowance.eur).toBeCloseTo((459.84 - 29) / 29, 1)
  })

  test('a BRL spend costs what those reais would have become at the rate', () => {
    const inEur = 100 / 5.868553
    const { allowance } = summarizeMonth(month, october, { ...context, spends: [{ day: 3, amount: 100, currency: 'BRL' }, eur(3, 10)] }, oct3)
    expect(allowance.spentToday).toBeCloseTo(inEur + 10, 2)
    expect(spendInEur({ amount: 100, currency: 'BRL' }, { rate: 5.868553 })).toBeCloseTo(inEur, 2)
    expect(spendInEur({ amount: 100, currency: 'BRL' }, { rate: null })).toBeNull()
    expect(spendInEur({ amount: 12.5, currency: 'EUR' }, { rate: null })).toBe(12.5)
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
  const context = { rate: 5.868553 }
  const eur = (day: number, amount: number) => ({ day, amount, currency: 'EUR' as const })
  const net = 459.84 // October EUR net (see 'computes the month totals')

  test('replays closed days, matches the open day and projects upcoming ones', () => {
    const spends = [eur(1, 30), eur(2, 100), eur(3, 10)]
    const summary = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends }, new Date(2026, 9, 3))
    const days = dayResults(month, summary, spends)
    expect(days).toHaveLength(31)

    const [first, second, third, fourth] = days
    expect(first).toMatchObject({ state: 'closed', spent: 30 })
    expect(first!.budget).toBeCloseTo(net / 31, 1)
    expect(first!.result).toBeCloseTo(net / 31 - 30, 1)
    expect(second!.budget).toBeCloseTo((net - 30) / 30, 1)
    expect(second!.result).toBeLessThan(0)

    expect(third).toMatchObject({ state: 'open', budget: summary.allowance.eur, spent: 10, result: summary.allowance.remainingEur })
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

describe('conversions', () => {
  test('the fee is what was sent beyond what the received EUR are worth at the rate', () => {
    expect(conversionFee({ sentBrl: 3000, receivedEur: 480 }, 6)).toBe(120)
    expect(conversionFee({ sentBrl: 1000, receivedEur: 163.31 }, 5.868553)).toBe(41.61)
    // The rate moved in the sender's favour, or there is none: no fee rather than a negative one.
    expect(conversionFee({ sentBrl: 3000, receivedEur: 520 }, 6)).toBe(0)
    expect(conversionFee({ sentBrl: 3000, receivedEur: 480 }, null)).toBe(0)
  })

  test('completed conversions count as they happened, and the rest is projected without a fee', () => {
    const { transfer } = summarizeMonth(month, october, { rate: 6, conversions: [{ sentBrl: 3000, feeBrl: 120, receivedEur: 480 }] }, new Date(2026, 9, 3))
    expect(transfer.realized).toEqual({ sentBrl: 3000, convertedBrl: 2880, feeBrl: 120, receivedEur: 480 })
    expect(transfer.remainingBrl).toBe(7738.52)
    expect(transfer.projected).toEqual({ sentBrl: 7738.52, eur: 1289.75 })
    expect(transfer.eur).toBe(1769.75)
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
