import type { Currency, DailySpend, Month, MonthItem, Rates } from './schemas'
import { currencies } from './schemas'

export interface CurrencyTotals {
  income: number
  expenses: number
  net: number
  paid: number
  pending: number
  /** Items still missing a value or flagged for review. */
  unresolved: number
}

/** How what is left in a currency other than the month's main one becomes main currency. */
export interface CurrencyConversion {
  currency: Currency
  /** How many units of the currency one unit of the main currency is worth; `null` when there is no rate for it. */
  rate: number | null
  /** Whether the rate is the one the month locked, rather than the live one. */
  rateLocked: boolean
  /** The currency's own net: its income minus its expenses. */
  net: number
  /** That net in the main currency, with no fee taken off; `null` when it isn't zero and there is no rate. */
  converted: number | null
}

export interface MonthSummary {
  /** The currency the month is worked out in. */
  main: Currency
  /** Totals of each currency's own items: the main currency, and every other one with an item. */
  totals: Partial<Record<Currency, CurrencyTotals>>
  /** The rate in use for each currency: the month's locked one, or the live one. */
  rates: Rates
  /** One entry per other currency the month has items or spends in, in the app's order. */
  conversions: CurrencyConversion[]
  /** What the other currencies add up to in the main one; `null` while any of them can't be converted. */
  converted: number | null
  /** The main currency's own net plus `converted`; `null` while `converted` is. */
  net: number | null
  /** Daily spending, all in the main currency. */
  allowance: {
    /** Day of the month open for daily spending; `null` for past months and once every day was closed. */
    activeDay: number | null
    /** Days the budget is spread over: from the open day to the end of the month. */
    days: number
    /** Daily spending on days other than the open day (normally the closed ones); it already came out of the budget being spread. */
    spentBefore: number
    /** Daily spending on the open day (spends in other currencies converted with `spendInMain`). */
    spentToday: number
    /** All daily spending of the month. */
    spentTotal: number
    /** Budget for the open day: (net − spentBefore) ÷ days. */
    amount: number | null
    /** What is left of the open day's budget after its spending. */
    remaining: number | null
  }
}

export type MonthPhase = 'past' | 'current' | 'future'

export interface SummaryContext {
  /** Live rates quoted against the month's main currency, used for the currencies the month didn't lock. */
  rates: Rates | null
  /** Day-to-day spending recorded for the month. */
  spends?: Pick<DailySpend, 'day' | 'amount' | 'currency'>[]
}

const round = (value: number) => Math.round(value * 100) / 100

export function daysInMonth(year: number, month: number) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate()
}

export function monthPhase(year: number, month: number, today = new Date()): MonthPhase {
  const current = today.getFullYear() * 12 + today.getMonth()
  const target = year * 12 + (month - 1)
  if (target < current)
    return 'past'
  return target === current ? 'current' : 'future'
}

/** Mirrors the spreadsheet's `EOMONTH(TODAY(), 0) - TODAY() + 1`, extended to past and future months. */
export function remainingDays(year: number, month: number, today = new Date()) {
  const phase = monthPhase(year, month, today)
  if (phase === 'past')
    return 0
  if (phase === 'future')
    return daysInMonth(year, month)
  return daysInMonth(year, month) - today.getDate() + 1
}

/**
 * Day open for daily spending. Until a day is closed it follows the calendar (today, or the 1st
 * of a future month); after that it only moves when the day is closed.
 */
export function openDay(month: Pick<Month, 'year' | 'month' | 'activeDay'>, today = new Date()): number | null {
  const phase = monthPhase(month.year, month.month, today)
  if (phase === 'past')
    return null
  const day = month.activeDay ?? (phase === 'current' ? today.getDate() : 1)
  return day > daysInMonth(month.year, month.month) ? null : day
}

/**
 * Where "close day" moves the open day: to today when earlier days were left open, otherwise to
 * the next day. Past the last day means the month is done.
 */
export function nextActiveDay(month: Pick<Month, 'year' | 'month' | 'activeDay'>, today = new Date()): number | null {
  const current = openDay(month, today)
  if (current === null)
    return null
  const calendarDay = monthPhase(month.year, month.month, today) === 'current' ? today.getDate() : 0
  return Math.min(Math.max(calendarDay, current + 1), daysInMonth(month.year, month.month) + 1)
}

function totals(items: MonthItem[], currency: Currency): CurrencyTotals {
  const result: CurrencyTotals = { income: 0, expenses: 0, net: 0, paid: 0, pending: 0, unresolved: 0 }
  for (const item of items) {
    if (item.currency !== currency)
      continue
    if (item.amount === null || item.needsReview)
      result.unresolved++
    const value = item.amount ?? 0
    if (item.kind === 'income') {
      result.income += value
      continue
    }
    result.expenses += value
    if (item.paid)
      result.paid += value
    else
      result.pending += value
  }
  result.income = round(result.income)
  result.expenses = round(result.expenses)
  result.paid = round(result.paid)
  result.pending = round(result.pending)
  result.net = round(result.income - result.expenses)
  return result
}

/**
 * What a daily spend costs the allowance, in the month's main currency. Money spent in another
 * currency is money that won't become main currency, so it is worth what it would have become at
 * the rate: amount ÷ rate. `null` when its currency has no rate.
 */
export function spendInMain(spend: Pick<DailySpend, 'amount' | 'currency'>, summary: Pick<MonthSummary, 'main' | 'rates'>) {
  if (spend.currency === summary.main)
    return spend.amount
  const rate = summary.rates[spend.currency]
  return rate ? round(spend.amount / rate) : null
}

/**
 * Computes the month's result and allowance, in the month's main currency. What is left in every
 * other currency, above or below zero, is converted into it at that currency's rate, with no fee
 * taken off. The result is then split across the open days.
 */
export function summarizeMonth(
  month: Pick<Month, 'year' | 'month' | 'mainCurrency' | 'lockedRates' | 'activeDay'>,
  items: MonthItem[],
  context: SummaryContext,
  today = new Date(),
): MonthSummary {
  const main = month.mainCurrency
  const spends = context.spends ?? []
  const rates: Rates = { ...context.rates, ...month.lockedRates }
  delete rates[main]

  const used = new Set<Currency>([main, ...items.map(item => item.currency)])
  const byCurrency: MonthSummary['totals'] = {}
  for (const currency of currencies) {
    if (used.has(currency))
      byCurrency[currency] = totals(items, currency)
  }

  const converting = new Set<Currency>([...used, ...spends.map(spend => spend.currency)])
  converting.delete(main)
  const conversions: CurrencyConversion[] = currencies.filter(currency => converting.has(currency)).map((currency) => {
    const rate = rates[currency] ?? null
    const net = byCurrency[currency]?.net ?? 0
    return {
      currency,
      rate,
      rateLocked: month.lockedRates[currency] !== undefined,
      net,
      converted: net === 0 ? 0 : rate ? round(net / rate) : null,
    }
  })
  const converted = conversions.some(conversion => conversion.converted === null)
    ? null
    : round(conversions.reduce((sum, conversion) => sum + conversion.converted!, 0))
  const net = converted === null ? null : round(byCurrency[main]!.net + converted)

  // Daily spending is kept out of the net: days before the open day reduce what gets spread over
  // the remaining days, while the open day's spending only eats into that day's budget.
  const activeDay = openDay(month, today)
  const days = activeDay === null ? 0 : daysInMonth(month.year, month.month) - activeDay + 1
  let spentBefore = 0
  let spentToday = 0
  let spentTotal = 0
  for (const spend of spends) {
    // Without a rate a spend in another currency can't be converted; it counts once a rate is available.
    const value = spendInMain(spend, { main, rates }) ?? 0
    spentTotal += value
    // Spends on later days only exist after undoing a close; they are still money already gone.
    if (spend.day === activeDay)
      spentToday += value
    else
      spentBefore += value
  }
  const amount = days > 0 && net !== null ? round((net - spentBefore) / days) : null

  return {
    main,
    totals: byCurrency,
    rates,
    conversions,
    converted,
    net,
    allowance: {
      activeDay,
      days,
      spentBefore: round(spentBefore),
      spentToday: round(spentToday),
      spentTotal: round(spentTotal),
      amount,
      remaining: amount === null ? null : round(amount - spentToday),
    },
  }
}

export interface DayResult {
  day: number
  /** closed: before the open day; open: the day spends go to; upcoming: not reached yet */
  state: 'closed' | 'open' | 'upcoming'
  /** The day's budget, in the main currency; for upcoming days, what they'd get if the open day closed now. */
  budget: number | null
  /** Daily spending on the day, in the main currency. */
  spent: number
  /** budget − spent: what was left (or, negative, what went over); for the open day, what's still left. */
  result: number | null
}

/**
 * Per-day budgets and results for a month's calendar. Budgets aren't stored, so closed days are
 * rebuilt by replaying the month as if each day had been closed in order: a day's budget is
 * (net − spends on earlier days) ÷ days from it to the end of the month. The open day uses the
 * summary's own figures, so it matches Hoje.
 */
export function dayResults(
  month: Pick<Month, 'year' | 'month'>,
  summary: MonthSummary,
  spends: Pick<DailySpend, 'day' | 'amount' | 'currency'>[],
): DayResult[] {
  const total = daysInMonth(month.year, month.month)
  const openDay = summary.allowance.activeDay
  const net = summary.net
  const spentOn = Array.from<number>({ length: total + 2 }).fill(0)
  for (const spend of spends)
    spentOn[spend.day] = (spentOn[spend.day] ?? 0) + (spendInMain(spend, summary) ?? 0)
  const spentAll = spentOn.reduce((sum, value) => sum + value, 0)
  // Upcoming days: what the open day's close would leave for each of the days after it.
  const upcomingDays = openDay === null ? 0 : total - openDay
  const projected = net !== null && upcomingDays > 0 ? round((net - spentAll) / upcomingDays) : null

  const results: DayResult[] = []
  let spentBefore = 0
  for (let day = 1; day <= total; day++) {
    const spent = round(spentOn[day] ?? 0)
    if (openDay !== null && day === openDay) {
      results.push({ day, state: 'open', budget: summary.allowance.amount, spent: summary.allowance.spentToday, result: summary.allowance.remaining })
    }
    else if (openDay !== null && day > openDay) {
      results.push({ day, state: 'upcoming', budget: projected, spent, result: projected })
    }
    else {
      const budget = net === null ? null : round((net - spentBefore) / (total - day + 1))
      results.push({ day, state: 'closed', budget, spent, result: budget === null ? null : round(budget - spent) })
    }
    spentBefore += spentOn[day] ?? 0
  }
  return results
}
