import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { eq } from 'drizzle-orm'
import { Hono } from 'hono'
import { months, templateItems } from '../db/schema'

/**
 * Wipes the user's data: months (with their items, spends and conversions) and template.
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
