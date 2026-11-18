import type { Conversion, DailySpend, LiveRate, Month, MonthItem, Settings, TemplateItem, WiseQuote } from './schemas'
import type { MonthSummary } from './summary'

/** `GET /api/months` row. Summary uses the month's locked rate or the current live rate. */
export type MonthListEntry = Month & {
  summary: MonthSummary
}

/** `GET /api/months/:year/:month` */
export interface MonthDetail {
  month: Month
  items: MonthItem[]
  /** Day-to-day spending, oldest first. */
  spends: DailySpend[]
  /** Completed BRL→EUR conversions, oldest first. */
  conversions: Conversion[]
  summary: MonthSummary
  rate: LiveRate | null
  /** Why the live providers failed; present with a missing or stale rate. */
  rateError: string | null
  /** Wise's quote for the BRL still projected to be converted. */
  quote: WiseQuote | null
  /** Settings fee, used when there's no manual fee and no quote. */
  fallbackFee: number
}

/** `GET /api/template` */
export interface TemplateDetail {
  items: TemplateItem[]
  settings: Settings
}

export interface ApiError {
  error: string
  issues?: unknown
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
