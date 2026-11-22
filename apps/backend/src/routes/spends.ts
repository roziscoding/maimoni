import type { DailySpend } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { createDailySpendSchema, daysInMonth, monthKeySchema, updateDailySpendSchema } from '@maimoni/shared'
import { and, asc, eq } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { dailySpends } from '../db/schema'
import { validate } from '../lib/validate'
import { CURRENCY_NOT_ADDED, userHasCurrency } from './currencies'
import { findMonth } from './months'

const spendParam = monthKeySchema.extend({ id: z.uuid() })

export function toDailySpend(row: typeof dailySpends.$inferSelect): DailySpend {
  const { updatedAt: _updatedAt, userId: _userId, ...spend } = row
  return { ...spend, createdAt: new Date(spend.createdAt).toISOString() }
}

export async function listSpends(db: Database, monthId: string) {
  const rows = await db.select().from(dailySpends).where(eq(dailySpends.monthId, monthId)).orderBy(asc(dailySpends.day), asc(dailySpends.createdAt))
  return rows.map(toDailySpend)
}

/**
 * Day-to-day spending. The client sends the day (the open day it shows), so day boundaries follow
 * the browser's timezone rather than the server's.
 */
export function spendRoutes(db: Database) {
  return new Hono<AuthEnv>()
    .post('/months/:year/:month/spends', validate('param', monthKeySchema), validate('json', createDailySpendSchema), async (c) => {
      const key = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (input.day > daysInMonth(key.year, key.month))
        return c.json({ error: 'Day is outside the month' }, 400)
      if (!await userHasCurrency(db, row.userId, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      const [spend] = await db.insert(dailySpends).values({ ...input, monthId: row.id, userId: row.userId }).returning()
      return c.json(toDailySpend(spend!), 201)
    })
    .patch('/months/:year/:month/spends/:id', validate('param', spendParam), validate('json', updateDailySpendSchema), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (input.day !== undefined && input.day > daysInMonth(key.year, key.month))
        return c.json({ error: 'Day is outside the month' }, 400)
      if (input.currency && !await userHasCurrency(db, row.userId, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      // A plain amount replaces whatever expression produced the previous one.
      const expression = input.amount !== undefined && input.expression === undefined ? null : input.expression
      const [spend] = await db.update(dailySpends)
        .set({ ...input, expression })
        .where(and(eq(dailySpends.id, id), eq(dailySpends.monthId, row.id)))
        .returning()
      if (!spend)
        return c.json({ error: 'Spend not found' }, 404)
      return c.json(toDailySpend(spend))
    })
    .delete('/months/:year/:month/spends/:id', validate('param', spendParam), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const [spend] = await db.delete(dailySpends)
        .where(and(eq(dailySpends.id, id), eq(dailySpends.monthId, row.id)))
        .returning({ id: dailySpends.id })
      if (!spend)
        return c.json({ error: 'Spend not found' }, 404)
      return c.body(null, 204)
    })
}
