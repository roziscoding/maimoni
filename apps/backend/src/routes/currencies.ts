import type { Currency, UserCurrency } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { addUserCurrencySchema, currencySchema, updateUserCurrencySchema } from '@maimoni/shared'
import { and, asc, desc, eq } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { dailySpends, monthItems, templateItems, userCurrencies } from '../db/schema'
import { validate } from '../lib/validate'

const currencyParam = z.object({ currency: currencySchema })

function toUserCurrency(row: Pick<typeof userCurrencies.$inferSelect, 'currency' | 'enabled' | 'isMainCurrency'>): UserCurrency {
  return { currency: row.currency, enabled: row.enabled, main: row.isMainCurrency }
}

type Transaction = Parameters<Parameters<Database['transaction']>[0]>[0]

/** Takes the main mark off the user's main currency. It goes before another gets it: the unique index allows one main currency per user at any moment. */
async function demoteMain(tx: Transaction, userId: string) {
  await tx.update(userCurrencies).set({ isMainCurrency: false }).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.isMainCurrency, true)))
}

/** What a transaction returns in place of its result when the request can't go through. */
function refuse<Status extends 404 | 409>(status: Status, error: string) {
  return { refused: { status, error } }
}
const MAIN_DISABLED = 'A disabled currency can\'t be the main one'

/** The user's currencies, the main one first. */
async function listUserCurrencies(db: Database, userId: string) {
  const rows = await db.select().from(userCurrencies).where(eq(userCurrencies.userId, userId)).orderBy(desc(userCurrencies.isMainCurrency), asc(userCurrencies.currency))
  return rows.map(toUserCurrency)
}

/** Whether any of the user's template items, month items or daily spends is in that currency. */
async function currencyInUse(db: Database, userId: string, currency: Currency) {
  for (const table of [templateItems, monthItems, dailySpends]) {
    const [row] = await db.select({ userId: table.userId }).from(table).where(and(eq(table.userId, userId), eq(table.currency, currency))).limit(1)
    if (row)
      return true
  }
  return false
}

/**
 * Whether the user has that currency. Template items, month items and daily spends can only be
 * written in one of the user's currencies.
 */
export async function userHasCurrency(db: Database, userId: string, currency: Currency) {
  const [row] = await db.select({ currency: userCurrencies.currency }).from(userCurrencies).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency)))
  return Boolean(row)
}

/** The answer for a write in a currency the user doesn't have. */
export const CURRENCY_NOT_ADDED = { error: 'Currency is not one of the user\'s currencies' }

export function currencyRoutes(db: Database) {
  return new Hono<AuthEnv>()
    .get('/settings/currencies', async c => c.json(await listUserCurrencies(db, c.var.user.id)))
    .post('/settings/currencies', validate('json', addUserCurrencySchema), async (c) => {
      const userId = c.var.user.id
      const { currency, enabled, main } = c.req.valid('json')
      const result = await db.transaction(async (tx) => {
        const existing = await tx.select({ currency: userCurrencies.currency }).from(userCurrencies).where(eq(userCurrencies.userId, userId))
        if (existing.some(row => row.currency === currency))
          return refuse(409, 'Currency already added')
        // A user's first currency is their main one, whatever was asked.
        const isMainCurrency = main || existing.length === 0
        if (isMainCurrency && !enabled)
          return refuse(409, MAIN_DISABLED)
        if (isMainCurrency)
          await demoteMain(tx, userId)
        const [row] = await tx.insert(userCurrencies).values({ userId, currency, enabled, isMainCurrency }).returning()
        return { row: row! }
      })
      if ('refused' in result)
        return c.json({ error: result.refused.error }, result.refused.status)
      return c.json(toUserCurrency(result.row), 201)
    })
    .patch('/settings/currencies/:currency', validate('param', currencyParam), validate('json', updateUserCurrencySchema), async (c) => {
      const userId = c.var.user.id
      const { currency } = c.req.valid('param')
      const input = c.req.valid('json')
      const mine = and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency))
      const result = await db.transaction(async (tx) => {
        const [row] = await tx.select().from(userCurrencies).where(mine)
        if (!row)
          return refuse(404, 'Currency not found')
        const enabled = input.enabled ?? row.enabled
        const isMainCurrency = input.main ?? row.isMainCurrency
        if (row.isMainCurrency && !isMainCurrency)
          return refuse(409, 'Make another currency the main one instead')
        if (isMainCurrency && !enabled)
          return refuse(409, MAIN_DISABLED)
        if (isMainCurrency && !row.isMainCurrency)
          await demoteMain(tx, userId)
        await tx.update(userCurrencies).set({ enabled, isMainCurrency }).where(mine)
        return { currencies: await listUserCurrencies(tx, userId) }
      })
      if ('refused' in result)
        return c.json({ error: result.refused.error }, result.refused.status)
      return c.json(result.currencies)
    })
    .delete('/settings/currencies/:currency', validate('param', currencyParam), async (c) => {
      const userId = c.var.user.id
      const { currency } = c.req.valid('param')
      const mine = and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency))
      const result = await db.transaction(async (tx) => {
        const [row] = await tx.select().from(userCurrencies).where(mine)
        if (!row)
          return refuse(404, 'Currency not found')
        if (row.isMainCurrency)
          return refuse(409, 'The main currency can\'t be removed')
        if (await currencyInUse(tx, userId, currency))
          return refuse(409, 'Currency is in use')
        await tx.delete(userCurrencies).where(mine)
        return { removed: true }
      })
      if ('refused' in result)
        return c.json({ error: result.refused.error }, result.refused.status)
      return c.body(null, 204)
    })
}
