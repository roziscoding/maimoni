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

function toUserCurrency(row: Pick<typeof userCurrencies.$inferSelect, 'currency' | 'isMainCurrency'>): UserCurrency {
  return { currency: row.currency, isMain: row.isMainCurrency }
}

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
      const { currency, isMain } = c.req.valid('json')
      const row = await db.transaction(async (tx) => {
        const existing = await tx.select({ currency: userCurrencies.currency }).from(userCurrencies).where(eq(userCurrencies.userId, userId))
        if (existing.some(row => row.currency === currency))
          return null
        // The previous main one goes first: the unique index allows one main currency per user at any moment.
        if (isMain)
          await tx.update(userCurrencies).set({ isMainCurrency: false }).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.isMainCurrency, true)))
        // A user's first currency is their main one, whatever was asked.
        const [inserted] = await tx.insert(userCurrencies).values({ userId, currency, isMainCurrency: isMain || existing.length === 0 }).returning()
        return inserted!
      })
      if (!row)
        return c.json({ error: 'Currency already added' }, 409)
      return c.json(toUserCurrency(row), 201)
    })
    .patch('/settings/currencies/:currency', validate('param', currencyParam), validate('json', updateUserCurrencySchema), async (c) => {
      const userId = c.var.user.id
      const { currency } = c.req.valid('param')
      const found = await db.transaction(async (tx) => {
        const [row] = await tx.select({ currency: userCurrencies.currency }).from(userCurrencies).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency)))
        if (!row)
          return false
        await tx.update(userCurrencies).set({ isMainCurrency: false }).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.isMainCurrency, true)))
        await tx.update(userCurrencies).set({ isMainCurrency: true }).where(and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency)))
        return true
      })
      if (!found)
        return c.json({ error: 'Currency not found' }, 404)
      return c.json(await listUserCurrencies(db, userId))
    })
    .delete('/settings/currencies/:currency', validate('param', currencyParam), async (c) => {
      const userId = c.var.user.id
      const { currency } = c.req.valid('param')
      const mine = and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency))
      const refusal = await db.transaction(async (tx) => {
        const [row] = await tx.select().from(userCurrencies).where(mine)
        if (!row)
          return { error: 'Currency not found', status: 404 } as const
        if (row.isMainCurrency)
          return { error: 'The main currency can\'t be removed', status: 409 } as const
        if (await currencyInUse(tx, userId, currency))
          return { error: 'Currency is in use', status: 409 } as const
        await tx.delete(userCurrencies).where(mine)
        return null
      })
      if (refusal)
        return c.json({ error: refusal.error }, refusal.status)
      return c.body(null, 204)
    })
}
