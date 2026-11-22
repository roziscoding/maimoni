import type { Currency, DailySpend, Month, MonthItem } from './schemas'

export interface CurrencyTotals {
  income: number
  expenses: number
  net: number
  paid: number
  pending: number
  /** Items still missing a value or flagged for review. */
  unresolved: number
}

export interface MonthSummary {
  brl: CurrencyTotals
  eur: CurrencyTotals
  transfer: {
    /** EUR→BRL rate used for the conversion. */
    rate: number | null
    rateLocked: boolean
    /** The BRL net: what is left in reais after their expenses. */
    remainingBrl: number
    projected: {
      /** Positive BRL balance expected to be converted. */
      sentBrl: number
      /** Expected EUR for that BRL at the rate, with no fee taken off; `null` without a rate. */
      eur: number | null
    }
    /** EUR the BRL net is expected to become; `null` when there is BRL to convert and no rate. */
    eur: number | null
  }
  allowance: {
    /** Day of the month open for daily spending; `null` for past months and once every day was closed. */
    activeDay: number | null
    /** Days the budget is spread over: from the open day to the end of the month. */
    days: number
    /** Daily spending on days other than the open day (normally the closed ones); it already came out of the budget being spread. */
    spentBefore: number
    /** Daily spending on the open day, in EUR (BRL spends converted with `spendInEur`). */
    spentToday: number
    /** All daily spending of the month, in EUR. */
    spentTotal: number
    /** Budget for the open day: (EUR net − spentBefore) ÷ days. */
    eur: number | null
    /** What is left of the open day's budget after its spending. */
    remainingEur: number | null
    brl: number | null
  }
}

export type MonthPhase = 'past' | 'current' | 'future'

export interface SummaryContext {
  /** Live EUR→BRL rate, used unless the month locked its own. */
  rate: number | null
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
 * What a daily spend costs the EUR allowance. Reais spent are reais that won't be converted, so a
 * BRL spend is worth what it would have become at the rate: amount ÷ rate. `null` when a BRL spend
 * has no rate to convert with.
 */
export function spendInEur(spend: Pick<DailySpend, 'amount' | 'currency'>, transfer: Pick<MonthSummary['transfer'], 'rate'>) {
  if (spend.currency === 'EUR')
    return spend.amount
  return transfer.rate ? round(spend.amount / transfer.rate) : null
}

/**
 * Computes the month's result and allowance. The BRL net is projected into EUR at the rate, with
 * no fee taken off. EUR expenses are then paid from own plus projected EUR, and the remainder is
 * split across the open days.
 */
export function summarizeMonth(
  month: Pick<Month, 'year' | 'month' | 'exchangeRate' | 'activeDay'>,
  items: MonthItem[],
  context: SummaryContext,
  today = new Date(),
): MonthSummary {
  const brl = totals(items, 'BRL')
  const eurOwn = totals(items, 'EUR')
  const rate = month.exchangeRate ?? context.rate
  const remainingBrl = brl.net
  const projectedBrl = Math.max(0, remainingBrl)
  const projectedEur = projectedBrl === 0 ? 0 : rate ? round(projectedBrl / rate) : null
  const transferEur = projectedEur

  const eurIncome = round(eurOwn.income + (projectedEur ?? 0))
  const eur: CurrencyTotals = { ...eurOwn, income: eurIncome, net: round(eurIncome - eurOwn.expenses) }

  // Daily spending is kept out of the EUR totals: days before the open day reduce what gets spread
  // over the remaining days, while the open day's spending only eats into that day's budget.
  const activeDay = openDay(month, today)
  const days = activeDay === null ? 0 : daysInMonth(month.year, month.month) - activeDay + 1
  let spentBefore = 0
  let spentToday = 0
  let spentTotal = 0
  for (const spend of context.spends ?? []) {
    // Without a rate a BRL spend can't be converted; it counts once a rate is available.
    const value = spendInEur(spend, { rate }) ?? 0
    spentTotal += value
    // Spends on later days only exist after undoing a close; they are still money already gone.
    if (spend.day === activeDay)
      spentToday += value
    else
      spentBefore += value
  }
  const allowanceEur = days > 0 && transferEur !== null ? round((eur.net - spentBefore) / days) : null

  return {
    brl,
    eur,
    transfer: {
      rate,
      rateLocked: month.exchangeRate !== null,
      remainingBrl,
      projected: {
        sentBrl: round(projectedBrl),
        eur: projectedEur,
      },
      eur: transferEur,
    },
    allowance: {
      activeDay,
      days,
      spentBefore: round(spentBefore),
      spentToday: round(spentToday),
      spentTotal: round(spentTotal),
      eur: allowanceEur,
      remainingEur: allowanceEur === null ? null : round(allowanceEur - spentToday),
      brl: allowanceEur !== null && rate ? round(allowanceEur * rate) : null,
    },
  }
}

export interface DayResult {
  day: number
  /** closed: before the open day; open: the day spends go to; upcoming: not reached yet */
  state: 'closed' | 'open' | 'upcoming'
  /** The day's budget in EUR; for upcoming days, what they'd get if the open day closed now. */
  budget: number | null
  /** Daily spending on the day, in EUR. */
  spent: number
  /** budget − spent: what was left (or, negative, what went over); for the open day, what's still left. */
  result: number | null
}

/**
 * Per-day budgets and results for a month's calendar. Budgets aren't stored, so closed days are
 * rebuilt by replaying the month as if each day had been closed in order: a day's budget is
 * (EUR net − spends on earlier days) ÷ days from it to the end of the month. The open day uses the
 * summary's own figures, so it matches Hoje.
 */
export function dayResults(
  month: Pick<Month, 'year' | 'month'>,
  summary: MonthSummary,
  spends: Pick<DailySpend, 'day' | 'amount' | 'currency'>[],
): DayResult[] {
  const total = daysInMonth(month.year, month.month)
  const openDay = summary.allowance.activeDay
  const hasBudget = summary.transfer.eur !== null
  const spentOn = Array.from({ length: total + 2 }).fill(0)
  for (const spend of spends)
    spentOn[spend.day] = (spentOn[spend.day] ?? 0) + (spendInEur(spend, summary.transfer) ?? 0)
  const spentAll = spentOn.reduce((sum, value) => sum + value, 0)
  // Upcoming days: what the open day's close would leave for each of the days after it.
  const upcomingDays = openDay === null ? 0 : total - openDay
  const projected = hasBudget && upcomingDays > 0 ? round((summary.eur.net - spentAll) / upcomingDays) : null

  const results: DayResult[] = []
  let spentBefore = 0
  for (let day = 1; day <= total; day++) {
    const spent = round(spentOn[day] ?? 0)
    if (openDay !== null && day === openDay) {
      results.push({ day, state: 'open', budget: summary.allowance.eur, spent: summary.allowance.spentToday, result: summary.allowance.remainingEur })
    }
    else if (openDay !== null && day > openDay) {
      results.push({ day, state: 'upcoming', budget: projected, spent, result: projected })
    }
    else {
      const budget = hasBudget ? round((summary.eur.net - spentBefore) / (total - day + 1)) : null
      results.push({ day, state: 'closed', budget, spent, result: budget === null ? null : round(budget - spent) })
    }
    spentBefore += spentOn[day] ?? 0
  }
  return results
}
