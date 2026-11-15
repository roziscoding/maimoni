import type { Currency } from '@maimoni/shared'

const money = {
  BRL: new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }),
  EUR: new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'EUR' }),
}
const rate = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 4, maximumFractionDigits: 4 })
const percent = new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 2 })
const monthNames = new Intl.DateTimeFormat('pt-BR', { month: 'long', timeZone: 'UTC' })
const time = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' })

/** `R$ 1.250,99` / `€ 45,00`. Missing values render as an em dash. */
export function formatMoney(value: number | null | undefined, currency: Currency) {
  return value === null || value === undefined ? '—' : money[currency].format(value)
}

/** EUR→BRL rate with the 4 decimals the spreadsheet showed. */
export function formatRate(value: number | null | undefined) {
  return value === null || value === undefined ? '—' : `R$ ${rate.format(value)}`
}

/** Fraction to percent: `0.039` → `3,9%`. */
export function formatPercent(value: number) {
  return percent.format(value)
}

export function formatDateTime(iso: string) {
  return time.format(new Date(iso))
}

/** Capitalized pt-BR month name: `Outubro`. */
export function monthName(month: number) {
  const name = monthNames.format(new Date(Date.UTC(2000, month - 1, 1)))
  return name.charAt(0).toUpperCase() + name.slice(1)
}

export function monthLabel(year: number, month: number) {
  return `${monthName(month)} ${year}`
}

const dayNames = new Intl.DateTimeFormat('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })

/** Capitalized pt-BR day: `Sábado, 3 de outubro`. */
export function dayLabel(year: number, month: number, day: number) {
  const label = dayNames.format(new Date(year, month - 1, day))
  return label.charAt(0).toUpperCase() + label.slice(1)
}

/** Pulls the backend's `{ error }` message out of a failed `$fetch`. */
export function errorMessage(error: unknown) {
  const data = (error as { data?: { error?: string } } | null)?.data
  return data?.error ?? (error instanceof Error ? error.message : 'Erro inesperado')
}
