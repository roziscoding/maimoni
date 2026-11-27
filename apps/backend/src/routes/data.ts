import type { DataExport } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { asc, desc, eq } from 'drizzle-orm'
import { Hono } from 'hono'
import { months, templateItems, userCurrencies } from '../db/schema'
import { listItems, toMonth } from './months'
import { listSpends } from './spends'
import { listTemplateItems } from './template'

/** Everything the user keeps, in the file format the mobile app's local mode imports. */
export function exportRoutes(db: Database) {
  return new Hono<AuthEnv>()
    .get('/data/export', async (c) => {
      const userId = c.var.user.id
      const [currencies, template, monthRows] = await Promise.all([
        db.select().from(userCurrencies).where(eq(userCurrencies.userId, userId)).orderBy(desc(userCurrencies.isMainCurrency), asc(userCurrencies.currency)),
        listTemplateItems(db, userId),
        db.select().from(months).where(eq(months.userId, userId)).orderBy(desc(months.year), desc(months.month)),
      ])
      const body: DataExport = {
        format: 'maimoni-export',
        version: 1,
        exportedAt: new Date().toISOString(),
        currencies: currencies.map(row => ({ currency: row.currency, enabled: row.enabled, main: row.isMainCurrency })),
        template,
        months: await Promise.all(monthRows.map(async row => ({
          ...toMonth(row),
          items: await listItems(db, row.id),
          spends: await listSpends(db, row.id),
        }))),
      }
      return c.json(body)
    })
}

/**
 * Wipes the user's data: months (with their items and spends) and template.
 * Cached exchange rates are shared and stay.
 */
export function dataRoutes(db: Database) {
  return new Hono<AuthEnv>()
    .delete('/data', async (c) => {
      const userId = c.var.user.id
      await db.transaction(async (tx) => {
        await tx.delete(months).where(eq(months.userId, userId))
        await tx.delete(templateItems).where(eq(templateItems.userId, userId))
      })
      return c.body(null, 204)
    })
}
