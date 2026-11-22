import { relations, sql } from 'drizzle-orm'
import { boolean, check, foreignKey, index, integer, numeric, pgEnum, pgTable, primaryKey, smallint, text, timestamp, unique, uniqueIndex, uuid } from 'drizzle-orm/pg-core'
import { user } from './auth-schema'

export * from './auth-schema'

export const currency = pgEnum('currency', ['BRL', 'EUR'])
export const entryKind = pgEnum('entry_kind', ['income', 'expense'])

const money = (name: string) => numeric(name, { precision: 14, scale: 2, mode: 'number' })
const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true, mode: 'string' }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'string' }).notNull().defaultNow().$onUpdate(() => sql`now()`),
}
const owner = () => uuid('user_id').notNull().references(() => user.id, { onDelete: 'cascade', onUpdate: 'cascade' })

/*
 * Every user-owned table has its own `user_id`, so row-level security can check it directly. Tables
 * under a month reference it through `(month_id, user_id)`, which keeps their owner equal to the month's.
 */

/** The currencies a user works with. Exactly one of them can be the main one. */
export const userCurrencies = pgTable('user_currencies', {
  userId: owner(),
  currency: currency('currency').notNull(),
  isMainCurrency: boolean('is_main_currency').notNull().default(false),
  ...timestamps,
}, table => [
  primaryKey({ name: 'user_currencies_pkey', columns: [table.userId, table.currency] }),
  uniqueIndex('user_currencies_main').on(table.userId).where(sql`${table.isMainCurrency}`),
])

export const templateItems = pgTable('template_items', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: owner(),
  name: text('name').notNull(),
  currency: currency('currency').notNull(),
  kind: entryKind('kind').notNull().default('expense'),
  amount: money('amount'),
  expression: text('expression'),
  variable: boolean('variable').notNull().default(false),
  position: integer('position').notNull().default(0),
  ...timestamps,
}, table => [index('template_items_user_id').on(table.userId)])

/** A user's month. Its items, spends and conversions belong to whoever owns the month. */
export const months = pgTable('months', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: owner(),
  year: smallint('year').notNull(),
  month: smallint('month').notNull(),
  exchangeRate: numeric('exchange_rate', { precision: 12, scale: 6, mode: 'number' }),
  activeDay: smallint('active_day'),
  note: text('note'),
  ...timestamps,
}, table => [
  unique('months_user_id_year_month').on(table.userId, table.year, table.month),
  unique('months_id_user_id').on(table.id, table.userId),
  check('months_month_range', sql`${table.month} between 1 and 12`),
  check('months_active_day_range', sql`${table.activeDay} between 1 and 32`),
])

/** Day-to-day spending (EUR or BRL), kept apart from the month's obligations (`month_items`). */
export const dailySpends = pgTable('daily_spends', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: owner(),
  monthId: uuid('month_id').notNull(),
  day: smallint('day').notNull(),
  currency: currency('currency').notNull().default('EUR'),
  amount: money('amount').notNull(),
  expression: text('expression'),
  note: text('note'),
  ...timestamps,
}, table => [
  foreignKey({ name: 'daily_spends_month', columns: [table.monthId, table.userId], foreignColumns: [months.id, months.userId] }).onDelete('cascade'),
  index('daily_spends_month_id_day').on(table.monthId, table.day),
  check('daily_spends_day_range', sql`${table.day} between 1 and 31`),
])

/** Completed BRL→EUR conversions. The sent amount includes the fee, which is worked out from the exchange rate when the conversion is saved. */
export const conversions = pgTable('conversions', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: owner(),
  monthId: uuid('month_id').notNull(),
  day: smallint('day').notNull(),
  sentBrl: money('sent_brl').notNull(),
  feeBrl: money('fee_brl').notNull(),
  receivedEur: money('received_eur').notNull(),
  note: text('note'),
  ...timestamps,
}, table => [
  foreignKey({ name: 'conversions_month', columns: [table.monthId, table.userId], foreignColumns: [months.id, months.userId] }).onDelete('cascade'),
  index('conversions_month_id_day').on(table.monthId, table.day),
  check('conversions_day_range', sql`${table.day} between 1 and 31`),
  check('conversions_sent_positive', sql`${table.sentBrl} > 0`),
  check('conversions_fee_range', sql`${table.feeBrl} >= 0 and ${table.feeBrl} <= ${table.sentBrl}`),
  check('conversions_received_positive', sql`${table.receivedEur} > 0`),
])

export const monthItems = pgTable('month_items', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: owner(),
  monthId: uuid('month_id').notNull(),
  templateItemId: uuid('template_item_id').references(() => templateItems.id, { onDelete: 'set null' }),
  name: text('name').notNull(),
  currency: currency('currency').notNull(),
  kind: entryKind('kind').notNull().default('expense'),
  amount: money('amount'),
  expression: text('expression'),
  paid: boolean('paid').notNull().default(false),
  needsReview: boolean('needs_review').notNull().default(false),
  position: integer('position').notNull().default(0),
  ...timestamps,
}, table => [
  foreignKey({ name: 'month_items_month', columns: [table.monthId, table.userId], foreignColumns: [months.id, months.userId] }).onDelete('cascade'),
  index('month_items_month_id').on(table.monthId),
])

/** Every successful live-rate lookup, used as fallback when all providers are down. */
export const exchangeRates = pgTable('exchange_rates', {
  id: uuid('id').primaryKey().defaultRandom(),
  base: currency('base').notNull(),
  quote: currency('quote').notNull(),
  rate: numeric('rate', { precision: 12, scale: 6, mode: 'number' }).notNull(),
  source: text('source').notNull(),
  fetchedAt: timestamp('fetched_at', { withTimezone: true, mode: 'string' }).notNull().defaultNow(),
}, table => [index('exchange_rates_pair_fetched_at').on(table.base, table.quote, table.fetchedAt)])

export const monthsRelations = relations(months, ({ many }) => ({ items: many(monthItems), conversions: many(conversions) }))
export const monthItemsRelations = relations(monthItems, ({ one }) => ({
  month: one(months, { fields: [monthItems.monthId], references: [months.id] }),
  templateItem: one(templateItems, { fields: [monthItems.templateItemId], references: [templateItems.id] }),
}))
export const conversionsRelations = relations(conversions, ({ one }) => ({
  month: one(months, { fields: [conversions.monthId], references: [months.id] }),
}))
