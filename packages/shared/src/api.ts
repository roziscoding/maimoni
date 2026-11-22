import type { Currency, DailySpend, LiveRates, Month, MonthItem, TemplateItem } from './schemas'
import type { MonthSummary } from './summary'

/** `GET /api/months` row. Summary uses the month's locked rates, and the current live ones for the rest. */
export type MonthListEntry = Month & {
  summary: MonthSummary
}

/** `GET /api/months/:year/:month` */
export interface MonthDetail {
  month: Month
  items: MonthItem[]
  /** Day-to-day spending, oldest first. */
  spends: DailySpend[]
  summary: MonthSummary
  /** Live rates quoted against the month's main currency. */
  rates: LiveRates | null
  /** Why the live providers failed; present with missing or stale rates. */
  rateError: string | null
}

/** `GET /api/template` */
export interface TemplateDetail {
  items: TemplateItem[]
}

export interface ApiError {
  error: string
  issues?: unknown
}

/** The 409 of `PUT /api/settings/currencies` when the list leaves out currencies that items or spends are in. */
export interface CurrenciesInUseError extends ApiError {
  /** The currencies left out that are in use. */
  inUse: Currency[]
}

/** `GET /api/flags`: what this server has switched on, so the clients know what to offer. */
export interface Flags {
  /** Whether `DELETE /api/data` is served (`FLAG_ENABLE_PURGE`). */
  purge: boolean
}

/** `GET /api/sessions` row: one sign in to the account that is still valid. */
export interface SessionEntry {
  id: string
  /** Whether this is the session that made the request. */
  current: boolean
  /** `User-Agent` of the sign in request. */
  userAgent: string | null
  /** Address the sign in came from, as the server saw it. */
  ipAddress: string | null
  createdAt: string
}
