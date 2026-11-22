import { z } from 'zod'

export const currencies = ['BRL', 'EUR'] as const
export const currencySchema = z.enum(currencies)
export type Currency = z.infer<typeof currencySchema>

export const entryKinds = ['income', 'expense'] as const
export const entryKindSchema = z.enum(entryKinds)
export type EntryKind = z.infer<typeof entryKindSchema>

const id = z.uuid()
const name = z.string().trim().min(1).max(120)
/** Money amount rounded to cents. `null` means "not filled in yet". */
const amount = z.number().finite().transform(value => Math.round(value * 100) / 100)
/** Optional arithmetic expression the amount was typed as (e.g. `11.99+2.99`). */
const expression = z.string().trim().max(200).nullable()
/**
 * Exchange rates by currency, all quoted against one other currency (a month's main one): how many
 * units of the key that one is worth. A currency left out has no rate.
 */
export const ratesSchema = z.partialRecord(currencySchema, z.number().positive())
export type Rates = z.infer<typeof ratesSchema>

/* -------------------------------------------------------------------------- */
/*                                    Auth                                    */
/* -------------------------------------------------------------------------- */

export const passwordResetRequestSchema = z.object({
  email: z.email().max(320),
})
export type PasswordResetRequest = z.infer<typeof passwordResetRequestSchema>

/* -------------------------------------------------------------------------- */
/*                                  Settings                                  */
/* -------------------------------------------------------------------------- */

/** A currency the user works with. Exactly one of a user's currencies is the main one. */
export const userCurrencySchema = z.object({
  currency: currencySchema,
  /**
   * Whether the clients offer it. A currency with history can be disabled instead of removed; the
   * server accepts items and spends in a disabled one all the same.
   */
  enabled: z.boolean(),
  main: z.boolean(),
  /** Whether a template item, month item or daily spend is in it. One in use can be disabled, not removed. */
  inUse: z.boolean(),
})
export type UserCurrency = z.infer<typeof userCurrencySchema>

const mainIsEnabled = {
  check: (value: { enabled?: boolean, main?: boolean }) => !(value.enabled === false && value.main === true),
  params: { error: 'A disabled currency can\'t be the main one', path: ['main'] },
}

/** `main: true` makes the new currency the main one, in place of the current one. */
export const addUserCurrencySchema = z.object({
  currency: currencySchema,
  enabled: z.boolean().default(true),
  main: z.boolean().default(false),
}).refine(mainIsEnabled.check, mainIsEnabled.params)
export type AddUserCurrency = z.input<typeof addUserCurrencySchema>

/** `main: true` takes the place of the current main currency. The main one stops being it when another becomes it, not through `main: false`. */
export const updateUserCurrencySchema = z.object({
  enabled: z.boolean().optional(),
  main: z.boolean().optional(),
}).refine(mainIsEnabled.check, mainIsEnabled.params)
export type UpdateUserCurrency = z.input<typeof updateUserCurrencySchema>

/** The user's whole list of currencies at once. `main` has to be one of `currencies`, and enabled. */
export const replaceUserCurrenciesSchema = z.object({
  currencies: z.array(z.object({ currency: currencySchema, enabled: z.boolean() })),
  main: currencySchema,
}).superRefine(({ currencies, main }, ctx) => {
  for (const [index, { currency }] of currencies.entries()) {
    if (currencies.findIndex(other => other.currency === currency) !== index)
      ctx.addIssue({ code: 'custom', message: 'Currency is listed more than once', path: ['currencies', index, 'currency'] })
  }
  const entry = currencies.find(({ currency }) => currency === main)
  if (!entry)
    ctx.addIssue({ code: 'custom', message: 'The main currency has to be one of the currencies', path: ['main'] })
  else if (!entry.enabled)
    ctx.addIssue({ code: 'custom', message: mainIsEnabled.params.error, path: ['main'] })
})
export type ReplaceUserCurrencies = z.input<typeof replaceUserCurrenciesSchema>

/* -------------------------------------------------------------------------- */
/*                                  Template                                  */
/* -------------------------------------------------------------------------- */

export const templateItemSchema = z.object({
  id,
  name: z.string(),
  currency: currencySchema,
  kind: entryKindSchema,
  amount: z.number().nullable(),
  expression,
  /** Variable items change every month: their value is only an estimate (or empty) when a month is created. */
  variable: z.boolean(),
  position: z.number().int(),
})
export type TemplateItem = z.infer<typeof templateItemSchema>

// Update schemas are built from these default-free shapes: in Zod 4 a `.default()` still fills in
// missing keys after `.partial()`, which would reset every field a PATCH didn't send.
const templateItemFields = z.object({
  name,
  currency: currencySchema,
  kind: entryKindSchema,
  amount: amount.nullable(),
  expression,
  variable: z.boolean(),
})

export const createTemplateItemSchema = templateItemFields.extend({
  kind: entryKindSchema.default('expense'),
  amount: amount.nullable().default(null),
  expression: expression.default(null),
  variable: z.boolean().default(false),
})
export type CreateTemplateItem = z.input<typeof createTemplateItemSchema>

export const updateTemplateItemSchema = templateItemFields.partial()
export type UpdateTemplateItem = z.input<typeof updateTemplateItemSchema>

export const reorderSchema = z.object({
  // Each ID costs one UPDATE, so the list is capped and a repeated ID is refused.
  ids: z.array(id).min(1).max(500).refine(ids => new Set(ids).size === ids.length, 'IDs must not repeat'),
})
export type Reorder = z.infer<typeof reorderSchema>

/* -------------------------------------------------------------------------- */
/*                                   Months                                   */
/* -------------------------------------------------------------------------- */

export const monthKeySchema = z.object({
  year: z.coerce.number().int().min(2000).max(2100),
  month: z.coerce.number().int().min(1).max(12),
})
export type MonthKey = z.infer<typeof monthKeySchema>

export const monthItemSchema = z.object({
  id,
  monthId: id,
  templateItemId: id.nullable(),
  name: z.string(),
  currency: currencySchema,
  kind: entryKindSchema,
  amount: z.number().nullable(),
  expression,
  paid: z.boolean(),
  /** True while a variable value copied from the template hasn't been confirmed for this month. */
  needsReview: z.boolean(),
  position: z.number().int(),
})
export type MonthItem = z.infer<typeof monthItemSchema>

const monthItemFields = z.object({
  name,
  currency: currencySchema,
  kind: entryKindSchema,
  amount: amount.nullable(),
  expression,
  paid: z.boolean(),
})

export const createMonthItemSchema = monthItemFields.extend({
  kind: entryKindSchema.default('expense'),
  amount: amount.nullable().default(null),
  expression: expression.default(null),
  paid: z.boolean().default(false),
})
export type CreateMonthItem = z.input<typeof createMonthItemSchema>

export const updateMonthItemSchema = monthItemFields.partial().extend({
  needsReview: z.boolean().optional(),
})
export type UpdateMonthItem = z.input<typeof updateMonthItemSchema>

export const monthSchema = z.object({
  id,
  year: z.number().int(),
  month: z.number().int(),
  /**
   * The currency the month is worked out in: the user's main currency when it was created. Changing
   * the main currency later leaves existing months as they were.
   */
  mainCurrency: currencySchema,
  /** Rates the month froze, by currency. A currency left out follows the live rate. */
  lockedRates: ratesSchema,
  /**
   * Day of the month open for daily spending. `null` means no day was closed yet, so the open day
   * is today. Past the last day means every day was closed.
   */
  activeDay: z.number().int().nullable(),
  note: z.string().nullable(),
  createdAt: z.string(),
})
export type Month = z.infer<typeof monthSchema>

export const createMonthSchema = z.object({
  year: z.number().int().min(2000).max(2100),
  month: z.number().int().min(1).max(12),
  /** Where the items come from: the template (default) or the latest existing month before this one. */
  source: z.enum(['template', 'previous']).default('template'),
})
export type CreateMonth = z.input<typeof createMonthSchema>

export const updateMonthSchema = z.object({
  /** Replaces every locked rate: a currency left out goes back to the live rate, and `{}` unlocks all. */
  lockedRates: ratesSchema.optional(),
  activeDay: z.number().int().min(1).max(32).nullable().optional(),
  note: z.string().trim().max(2000).nullable().optional(),
})
export type UpdateMonth = z.input<typeof updateMonthSchema>

/* -------------------------------------------------------------------------- */
/*                                Daily spends                                */
/* -------------------------------------------------------------------------- */

/**
 * Day-to-day spending, kept apart from the month's obligations. A spend in another currency counts
 * against the allowance as what it would have become in the month's main one (see `spendInMain`).
 */
export const dailySpendSchema = z.object({
  id,
  monthId: id,
  day: z.number().int(),
  currency: currencySchema,
  amount: z.number(),
  expression,
  note: z.string().nullable(),
  createdAt: z.string(),
})
export type DailySpend = z.infer<typeof dailySpendSchema>

const dailySpendFields = z.object({
  day: z.number().int().min(1).max(31),
  currency: currencySchema,
  amount,
  expression,
  note: z.string().trim().max(200).nullable(),
})

export const createDailySpendSchema = dailySpendFields.extend({
  /** Left out, the spend goes in the month's main currency. */
  currency: currencySchema.optional(),
  expression: expression.default(null),
  note: z.string().trim().max(200).nullable().default(null),
})
export type CreateDailySpend = z.input<typeof createDailySpendSchema>

export const updateDailySpendSchema = dailySpendFields.partial()
export type UpdateDailySpend = z.input<typeof updateDailySpendSchema>

/* -------------------------------------------------------------------------- */
/*                                Exchange rate                               */
/* -------------------------------------------------------------------------- */

export const rateSourceSchema = z.enum(['frankfurter', 'open-er-api', 'cache'])
export const liveRatesSchema = z.object({
  /** The currency the rates are quoted against. */
  base: currencySchema,
  /** How many units of each other currency one unit of `base` costs. */
  rates: ratesSchema,
  source: rateSourceSchema,
  fetchedAt: z.string(),
  /** True when every provider failed and the last stored rates are being served. */
  stale: z.boolean(),
})
export type LiveRates = z.infer<typeof liveRatesSchema>
