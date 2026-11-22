import type { Currency } from '@maimoni/shared'

const money = {
  BRL: new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }),
  EUR: new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'EUR' }),
}
const rate = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 4, maximumFractionDigits: 4 })
const monthNames = new Intl.DateTimeFormat('pt-BR', { month: 'long', timeZone: 'UTC' })
const time = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' })

/** `R$ 1.250,99` / `€ 45,00`. Missing values render as an em dash. */
export function formatMoney(value: number | null | undefined, currency: Currency) {
  return value === null || value === undefined ? '—' : money[currency].format(value)
}

const currencyNames = new Intl.DisplayNames('pt-BR', { type: 'currency' })

/** pt-BR name of a currency: `Real brasileiro`, `Euro`. */
export function currencyName(currency: Currency) {
  const name = currencyNames.of(currency) ?? currency
  return name.charAt(0).toUpperCase() + name.slice(1)
}

const currencyPlurals = Object.fromEntries(Object.entries(money).map(([currency]) => [
  currency,
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency, currencyDisplay: 'name' }),
])) as Record<Currency, Intl.NumberFormat>

/** pt-BR plural name of a currency, for a heading over amounts in it: `Reais brasileiros`, `Euros`. */
export function currencyPlural(currency: Currency) {
  const name = currencyPlurals[currency].formatToParts(2).find(part => part.type === 'currency')?.value ?? currency
  return name.charAt(0).toUpperCase() + name.slice(1)
}

/** The sign a currency's amounts are written with: `R$`, `€`. */
export function currencySymbol(currency: Currency) {
  return money[currency].formatToParts(0).find(part => part.type === 'currency')?.value ?? currency
}

/** EUR→BRL rate with the 4 decimals the spreadsheet showed. */
export function formatRate(value: number | null | undefined) {
  return value === null || value === undefined ? '—' : `R$ ${rate.format(value)}`
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

const BROWSERS: [RegExp, string][] = [[/Edg\//, 'Edge'], [/OPR\//, 'Opera'], [/Firefox\//, 'Firefox'], [/Chrome\//, 'Chrome'], [/Safari\//, 'Safari']]
const SYSTEMS: [RegExp, string][] = [[/Android/i, 'Android'], [/iPhone|iPad|iOS/i, 'iPhone'], [/Mac OS X|macOS/i, 'macOS'], [/Windows/i, 'Windows'], [/Linux/i, 'Linux']]

/** Names the device behind a session's `User-Agent`: `Chrome no Linux`, `App maimoni no Android`. */
export function deviceLabel(userAgent: string | null) {
  if (!userAgent)
    return 'Dispositivo desconhecido'
  // The mobile app sends `maimoni-app (<system>)`; builds before that sent Dart's default.
  const app = /^maimoni-app|^Dart\//.test(userAgent)
  const name = app ? 'App maimoni' : BROWSERS.find(([pattern]) => pattern.test(userAgent))?.[1]
  const system = SYSTEMS.find(([pattern]) => pattern.test(userAgent))?.[1]
  if (!name)
    return system ?? 'Dispositivo desconhecido'
  return system ? `${name} no ${system}` : name
}

/**
 * Pulls the message out of a failed `$fetch`. The backend answers `{ error: string }`; when the
 * request never reaches it, Nuxt's proxy answers `{ error: true, statusMessage, message }` instead.
 */
export function errorMessage(error: unknown) {
  const data = (error as { data?: { error?: unknown, statusMessage?: unknown, message?: unknown } } | null)?.data
  const message = [data?.error, data?.statusMessage, data?.message].find(value => typeof value === 'string' && value)
  return typeof message === 'string' ? message : error instanceof Error ? error.message : 'Erro inesperado'
}
