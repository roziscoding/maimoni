import type { Conversion, Currency, DailySpend, Month, MonthItem, WiseQuote } from './schemas'

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
    /** Effective fee as a fraction of sentBrl. */
    wiseFee: number
    /** manual: the month's own percentage; wise: Wise's quote; fallback: settings percentage because there was no quote. */
    feeSource: FeeSource
    /** BRL left after completed conversions; negative when they exceeded this month's net. */
    remainingBrl: number
    realized: {
      /** Total BRL debited by completed conversions, fees included. */
      sentBrl: number
      convertedBrl: number
      feeBrl: number
      receivedEur: number
    }
    projected: {
      /** Positive BRL balance still expected to be converted. */
      sentBrl: number
      feeBrl: number
      /** Expected EUR for the remaining BRL; `null` without a rate. */
      eur: number | null
    }
    /** Completed EUR plus the projection for the remaining BRL. */
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

export type FeeSource = 'manual' | 'wise' | 'fallback'

export interface SummaryContext {
  /** Live EUR→BRL rate, used unless the month locked its own. */
  rate: number | null
  /** Wise quote for (ideally) this month's sentBrl; used when the month has no manual fee. */
  quote?: WiseQuote | null
  /** Percentage used when the month has no manual fee and there's no quote. */
  fallbackFee: number
  /** Day-to-day spending recorded for the month. */
  spends?: Pick<DailySpend, 'day' | 'amount' | 'currency'>[]
  /** Completed BRL→EUR conversions recorded for the month. */
  conversions?: Pick<Conversion, 'sentBrl' | 'feeBrl' | 'receivedEur'>[]
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
 * What a daily spend costs the EUR allowance. Reais spent are reais that won't go through Wise, so
 * a BRL spend is worth what it would have become there: amount × (1 − fee) ÷ rate. `null` when a
 * BRL spend has no rate to convert with.
 */
export function spendInEur(spend: Pick<DailySpend, 'amount' | 'currency'>, transfer: Pick<MonthSummary['transfer'], 'rate' | 'wiseFee'>) {
  if (spend.currency === 'EUR')
    return spend.amount
  return transfer.rate ? round((spend.amount * (1 - transfer.wiseFee)) / transfer.rate) : null
}

/**
 * Wise fee in BRL for sending `sentBrl`. A quote for a different amount (the month was edited
 * since it was fetched) is scaled by its effective percentage until a fresh one arrives.
 */
function wiseFee(month: Pick<Month, 'wiseFee'>, sentBrl: number, { quote, fallbackFee }: SummaryContext): { feeBrl: number, fraction: number, source: FeeSource } {
  if (month.wiseFee !== null)
    return { feeBrl: sentBrl * month.wiseFee, fraction: month.wiseFee, source: 'manual' }
  if (quote && quote.sendAmount > 0) {
    const fraction = quote.fee / quote.sendAmount
    return { feeBrl: quote.sendAmount === sentBrl ? quote.fee : sentBrl * fraction, fraction, source: 'wise' }
  }
  return { feeBrl: sentBrl * fallbackFee, fraction: fallbackFee, source: 'fallback' }
}

/**
 * Computes the month's result and allowance. Completed conversions use their actual BRL, fee and
 * EUR amounts; only the BRL left after them is projected through Wise. EUR expenses are then paid
 * from actual plus projected EUR, and the remainder is split across the open days.
 */
export function summarizeMonth(
  month: Pick<Month, 'year' | 'month' | 'wiseFee' | 'exchangeRate' | 'activeDay'>,
  items: MonthItem[],
  context: SummaryContext,
  today = new Date(),
): MonthSummary {
  const brl = totals(items, 'BRL')
  const eurOwn = totals(items, 'EUR')
  const rate = month.exchangeRate ?? context.rate
  const realized = (context.conversions ?? []).reduce((result, conversion) => ({
    sentBrl: result.sentBrl + conversion.sentBrl,
    convertedBrl: result.convertedBrl + conversion.sentBrl - conversion.feeBrl,
    feeBrl: result.feeBrl + conversion.feeBrl,
    receivedEur: result.receivedEur + conversion.receivedEur,
  }), { sentBrl: 0, convertedBrl: 0, feeBrl: 0, receivedEur: 0 })
  const remainingBrl = round(brl.net - realized.sentBrl)
  const projectedBrl = Math.max(0, remainingBrl)
  const fee = wiseFee(month, projectedBrl, context)
  const projectedEur = projectedBrl === 0 ? 0 : rate ? round((projectedBrl - fee.feeBrl) / rate) : null
  const transferEur = projectedEur === null ? null : round(realized.receivedEur + projectedEur)

  const eurIncome = round(eurOwn.income + realized.receivedEur + (projectedEur ?? 0))
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
    const value = spendInEur(spend, { rate, wiseFee: fee.fraction }) ?? 0
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
      wiseFee: fee.fraction,
      feeSource: fee.source,
      remainingBrl,
      realized: {
        sentBrl: round(realized.sentBrl),
        convertedBrl: round(realized.convertedBrl),
        feeBrl: round(realized.feeBrl),
        receivedEur: round(realized.receivedEur),
      },
      projected: {
        sentBrl: round(projectedBrl),
        feeBrl: round(fee.feeBrl),
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
