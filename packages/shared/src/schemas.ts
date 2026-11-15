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
/** Wise fee as a fraction (0.039 = 3.9%). */
export const wiseFeeSchema = z.number().min(0).lt(1)
export const exchangeRateSchema = z.number().positive()

/* -------------------------------------------------------------------------- */
/*                                    Auth                                    */
/* -------------------------------------------------------------------------- */

export const passwordResetRequestSchema = z.object({
  email: z.email().max(320),
})
export type PasswordResetRequest = z.infer<typeof passwordResetRequestSchema>

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
  ids: z.array(id).min(1),
})
export type Reorder = z.infer<typeof reorderSchema>

/* -------------------------------------------------------------------------- */
/*                                  Settings                                  */
/* -------------------------------------------------------------------------- */

export const settingsSchema = z.object({
  /** Fallback Wise fee: used when Wise can't be reached for a quote, and as the starting value for a manual fee. */
  wiseFee: wiseFeeSchema,
})
export type Settings = z.infer<typeof settingsSchema>

export const updateSettingsSchema = settingsSchema.partial()
export type UpdateSettings = z.infer<typeof updateSettingsSchema>

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
  /** Manual Wise fee as a fraction. `null` means the real fee quoted by Wise for the amount is used. */
  wiseFee: z.number().nullable(),
  /** Locked EUR→BRL rate. `null` means the live rate is used. */
  exchangeRate: z.number().nullable(),
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
  wiseFee: wiseFeeSchema.nullable().optional(),
  exchangeRate: exchangeRateSchema.nullable().optional(),
  activeDay: z.number().int().min(1).max(32).nullable().optional(),
  note: z.string().trim().max(2000).nullable().optional(),
})
export type UpdateMonth = z.input<typeof updateMonthSchema>

/* -------------------------------------------------------------------------- */
/*                                Conversions                                 */
/* -------------------------------------------------------------------------- */

export const conversionSchema = z.object({
  id,
  monthId: id,
  day: z.number().int(),
  /** Total BRL debited by Wise, including the fee. */
  sentBrl: z.number(),
  feeBrl: z.number(),
  receivedEur: z.number(),
  note: z.string().nullable(),
  createdAt: z.string(),
})
export type Conversion = z.infer<typeof conversionSchema>

const conversionFields = z.object({
  day: z.number().int().min(1).max(31),
  sentBrl: amount.pipe(z.number().positive()),
  feeBrl: amount.pipe(z.number().nonnegative()),
  receivedEur: amount.pipe(z.number().positive()),
  note: z.string().trim().max(200).transform(value => value || null).nullable(),
})

export const createConversionSchema = conversionFields.extend({
  note: conversionFields.shape.note.default(null),
}).refine(input => input.feeBrl <= input.sentBrl, {
  path: ['feeBrl'],
  message: 'Fee cannot exceed the total sent',
})
export type CreateConversion = z.input<typeof createConversionSchema>

export const updateConversionSchema = conversionFields.partial()
export type UpdateConversion = z.input<typeof updateConversionSchema>

/* -------------------------------------------------------------------------- */
/*                                Daily spends                                */
/* -------------------------------------------------------------------------- */

/**
 * Day-to-day spending, kept apart from the month's obligations. BRL spends count against the EUR
 * allowance as what those reais would have become through Wise (see `spendInEur`).
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
  currency: currencySchema.default('EUR'),
  expression: expression.default(null),
  note: z.string().trim().max(200).nullable().default(null),
})
export type CreateDailySpend = z.input<typeof createDailySpendSchema>

export const updateDailySpendSchema = dailySpendFields.partial()
export type UpdateDailySpend = z.input<typeof updateDailySpendSchema>

/* -------------------------------------------------------------------------- */
/*                                Exchange rate                               */
/* -------------------------------------------------------------------------- */

export const rateSourceSchema = z.enum(['wise', 'frankfurter', 'open-er-api', 'cache'])
export const liveRateSchema = z.object({
  base: z.literal('EUR'),
  quote: z.literal('BRL'),
  /** How many BRL one EUR costs. */
  rate: z.number(),
  source: rateSourceSchema,
  fetchedAt: z.string(),
  /** True when every provider failed and the last stored rate is being served. */
  stale: z.boolean(),
})
export type LiveRate = z.infer<typeof liveRateSchema>

/* -------------------------------------------------------------------------- */
/*                                 Wise quote                                 */
/* -------------------------------------------------------------------------- */

export const wiseQuoteQuerySchema = z.object({
  sendAmount: z.coerce.number().positive().max(10_000_000).optional(),
  recipientGetsAmount: z.coerce.number().positive().max(10_000_000).optional(),
}).refine(input => (input.sendAmount === undefined) !== (input.recipientGetsAmount === undefined), {
  message: 'Provide exactly one quote amount',
})
export type WiseQuoteQuery = z.infer<typeof wiseQuoteQuerySchema>

export const wiseQuoteSchema = z.object({
  /** BRL sent. */
  sendAmount: z.number(),
  /** Total Wise fee in BRL for this amount (fixed + variable part). */
  fee: z.number(),
  /** EUR that arrives. */
  receivedAmount: z.number(),
  /** EUR per BRL used by the quote (mid-market). */
  rate: z.number(),
  fetchedAt: z.string(),
})
export type WiseQuote = z.infer<typeof wiseQuoteSchema>
