import type { MonthItem } from './schemas'
import { describe, expect, test } from 'bun:test'
import { evaluateExpression, isExpression } from './expression'
import { dayResults, nextActiveDay, openDay, remainingDays, spendInEur, summarizeMonth } from './summary'

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
const month = { year: 2026, month: 10, wiseFee: 0.039, exchangeRate: null, activeDay: null }

describe('summarizeMonth', () => {
  test('computes the month totals', () => {
    const summary = summarizeMonth(month, october, { rate: 5.868553, fallbackFee: 0.039 }, new Date(2026, 9, 3))
    expect(summary.brl.expenses).toBe(9261.98)
    expect(summary.brl.net).toBe(10738.52)
    expect(summary.transfer.eur).toBeCloseTo(1758.48, 2)
    expect(summary.eur.expenses).toBe(1370)
    expect(summary.eur.net).toBeCloseTo(388.48, 2)
    expect(summary.allowance.days).toBe(29)
    expect(summary.allowance.eur).toBeCloseTo(13.4, 2)
    expect(summary.allowance.brl).toBeCloseTo(78.64, 1)
  })

  test('locked rate overrides the live value', () => {
    const summary = summarizeMonth({ ...month, exchangeRate: 6 }, october, { rate: 5.868553, fallbackFee: 0.039 }, new Date(2026, 9, 3))
    expect(summary.transfer.rate).toBe(6)
    expect(summary.transfer.rateLocked).toBe(true)
    expect(summary.transfer.projected.eur).toBeCloseTo((10738.52 * 0.961) / 6, 2)
    expect(summary.transfer.eur).toBe(summary.transfer.projected.eur)
  })

  test('counts empty and review items as unresolved, splits paid/pending', () => {
    const summary = summarizeMonth(month, [
      item({ currency: 'BRL', amount: null }),
      item({ currency: 'BRL', amount: 10, paid: true }),
      item({ currency: 'BRL', amount: 5, needsReview: true }),
    ], { rate: 5, fallbackFee: 0.039 }, new Date(2026, 9, 3))
    expect(summary.brl.unresolved).toBe(2)
    expect(summary.brl.paid).toBe(10)
    expect(summary.brl.pending).toBe(5)
  })

  test('no allowance without a rate or for past months', () => {
    expect(summarizeMonth(month, october, { rate: null, fallbackFee: 0.039 }, new Date(2026, 9, 3)).allowance.eur).toBeNull()
    expect(summarizeMonth(month, october, { rate: 5.8, fallbackFee: 0.039 }, new Date(2026, 10, 3)).allowance.eur).toBeNull()
  })
})

describe('daily allowance', () => {
  const context = { rate: 5.868553, fallbackFee: 0.039 }
  const oct3 = new Date(2026, 9, 3)
  // EUR net 388.48 over 29 days (3rd to 31st) = 13.40 a day
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
    expect(allowance.eur).toBeCloseTo((388.48 - 80) / 27, 1)
  })

  test('spends on a later day (left by undoing a close) still come out of the budget', () => {
    const { allowance } = summarizeMonth({ ...month, activeDay: 3 }, october, { ...context, spends: [eur(4, 29)] }, oct3)
    expect(allowance).toMatchObject({ spentBefore: 29, spentToday: 0 })
    expect(allowance.eur).toBeCloseTo((388.48 - 29) / 29, 1)
  })

  test('a BRL spend costs what those reais would have become through Wise', () => {
    const inEur = (100 * (1 - 0.039)) / 5.868553
    const { allowance } = summarizeMonth(month, october, { ...context, spends: [{ day: 3, amount: 100, currency: 'BRL' }, eur(3, 10)] }, oct3)
    expect(allowance.spentToday).toBeCloseTo(inEur + 10, 2)
    expect(spendInEur({ amount: 100, currency: 'BRL' }, { rate: 5.868553, wiseFee: 0.039 })).toBeCloseTo(inEur, 2)
    expect(spendInEur({ amount: 100, currency: 'BRL' }, { rate: null, wiseFee: 0.039 })).toBeNull()
    expect(spendInEur({ amount: 12.5, currency: 'EUR' }, { rate: null, wiseFee: 0.039 })).toBe(12.5)
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
  const context = { rate: 5.868553, fallbackFee: 0.039 }
  const eur = (day: number, amount: number) => ({ day, amount, currency: 'EUR' as const })
  const net = 388.48 // October EUR net (see 'computes the month totals')

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

describe('Wise fee', () => {
  const auto = { ...month, wiseFee: null }
  const quote = { sendAmount: 10738.52, fee: 429.24, receivedAmount: 1757.57, rate: 0.170484, fetchedAt: '' }

  test('uses the quoted fee for the exact amount', () => {
    const { transfer } = summarizeMonth(auto, october, { rate: 5.86565, quote, fallbackFee: 0.039 }, new Date(2026, 9, 3))
    expect(transfer).toMatchObject({ feeSource: 'wise', projected: { feeBrl: 429.24 } })
    expect(transfer.projected.eur).toBeCloseTo((10738.52 - 429.24) / 5.86565, 2)
    expect(transfer.wiseFee).toBeCloseTo(429.24 / 10738.52, 6)
  })

  test('scales a quote for a different amount by its percentage', () => {
    const { transfer } = summarizeMonth(auto, october, { rate: 5.86565, quote: { ...quote, sendAmount: 10000, fee: 399.72 }, fallbackFee: 0.039 }, new Date(2026, 9, 3))
    expect(transfer.projected.feeBrl).toBeCloseTo(10738.52 * 0.039972, 1)
  })

  test('falls back to the settings percentage without a quote, and manual fees win', () => {
    expect(summarizeMonth(auto, october, { rate: 5.86565, fallbackFee: 0.05 }).transfer).toMatchObject({ feeSource: 'fallback', wiseFee: 0.05 })
    expect(summarizeMonth(month, october, { rate: 5.86565, quote, fallbackFee: 0.05 }).transfer).toMatchObject({ feeSource: 'manual', wiseFee: 0.039 })
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
