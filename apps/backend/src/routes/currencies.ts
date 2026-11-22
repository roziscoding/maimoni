import type { CurrenciesInUseError, Currency, UserCurrency } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { addUserCurrencySchema, currencySchema, replaceUserCurrenciesSchema, updateUserCurrencySchema } from '@maimoni/shared'
import { and, asc, desc, eq, inArray } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { dailySpends, monthItems, templateItems, user, userCurrencies } from '../db/schema'
import { validate } from '../lib/validate'

const currencyParam = z.object({ currency: currencySchema })

function toUserCurrency(row: Pick<typeof userCurrencies.$inferSelect, 'currency' | 'enabled' | 'isMainCurrency'>): UserCurrency {
  return { currency: row.currency, enabled: row.enabled, main: row.isMainCurrency }
}

type Transaction = Parameters<Parameters<Database['transaction']>[0]>[0]

/**
 * Makes requests that change the same user's currencies wait for each other, until the transaction
 * ends. Each one decides from what it read (is the currency there, is it the main one, is it the
 * first), and the unique index only rules out two main currencies, not none.
 *
 * The lock is on the user's row because the list can be empty. `no key update` leaves inserts that
 * reference the user, such as a new item, free to go on.
 */
async function lockCurrencies(tx: Transaction, userId: string) {
  await tx.select({ id: user.id }).from(user).where(eq(user.id, userId)).for('no key update')
}

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
        await lockCurrencies(tx, userId)
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
    // Replaces the whole list: currencies left out are removed, which one in use refuses.
    .put('/settings/currencies', validate('json', replaceUserCurrenciesSchema), async (c) => {
      const userId = c.var.user.id
      const { currencies, main } = c.req.valid('json')
      const result = await db.transaction(async (tx) => {
        await lockCurrencies(tx, userId)
        const existing = await tx.select({ currency: userCurrencies.currency }).from(userCurrencies).where(eq(userCurrencies.userId, userId))
        const removed = existing.map(row => row.currency).filter(currency => !currencies.some(entry => entry.currency === currency))
        // All of them, so the client can name every currency that has to stay.
        const inUse: Currency[] = []
        for (const currency of removed) {
          if (await currencyInUse(tx, userId, currency))
            inUse.push(currency)
        }
        if (inUse.length)
          return { inUse }
        if (removed.length)
          await tx.delete(userCurrencies).where(and(eq(userCurrencies.userId, userId), inArray(userCurrencies.currency, removed)))
        await demoteMain(tx, userId)
        for (const { currency, enabled } of currencies) {
          const values = { enabled, isMainCurrency: currency === main }
          await tx.insert(userCurrencies).values({ userId, currency, ...values }).onConflictDoUpdate({ target: [userCurrencies.userId, userCurrencies.currency], set: values })
        }
        return { currencies: await listUserCurrencies(tx, userId) }
      })
      if (result.inUse) {
        const body: CurrenciesInUseError = { error: `In use: ${result.inUse.join(', ')}. Send them with enabled: false instead of leaving them out`, inUse: result.inUse }
        return c.json(body, 409)
      }
      return c.json(result.currencies)
    })
    .patch('/settings/currencies/:currency', validate('param', currencyParam), validate('json', updateUserCurrencySchema), async (c) => {
      const userId = c.var.user.id
      const { currency } = c.req.valid('param')
      const input = c.req.valid('json')
      const mine = and(eq(userCurrencies.userId, userId), eq(userCurrencies.currency, currency))
      const result = await db.transaction(async (tx) => {
        await lockCurrencies(tx, userId)
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
        await lockCurrencies(tx, userId)
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
