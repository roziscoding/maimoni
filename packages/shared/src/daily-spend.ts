import type { CreateDailySpend, Currency, DailySpend } from './schemas'
import { evaluateExpression, isExpression } from './expression'

export interface DailySpendDraft {
  day: number
  currency: Currency
  amountText: string
  note: string
}

export interface DailySpendGroup {
  day: number
  spends: DailySpend[]
}

export function groupDailySpends(spends: DailySpend[]): DailySpendGroup[] {
  const ordered = [...spends].sort((left, right) => right.day - left.day || left.createdAt.localeCompare(right.createdAt))
  return [...Map.groupBy(ordered, spend => spend.day)].map(([day, entries]) => ({ day, spends: entries }))
}

export function dailySpendInput({ day, currency, amountText, note }: DailySpendDraft): CreateDailySpend | null {
  const text = amountText.trim()
  const amount = evaluateExpression(text)
  if (amount === null)
    return null
  return {
    day,
    currency,
    amount,
    expression: isExpression(text) ? text.replace(/^=/, '') : null,
    note: note.trim() || null,
  }
}
