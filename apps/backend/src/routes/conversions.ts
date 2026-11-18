import type { Conversion } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import type { months } from '../db/schema'
import type { RateService } from '../services/rates'
import { conversionFee, createConversionSchema, daysInMonth, monthKeySchema, updateConversionSchema } from '@maimoni/shared'
import { and, asc, eq } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { conversions } from '../db/schema'
import { validate } from '../lib/validate'
import { findMonth } from './months'

const conversionParam = monthKeySchema.extend({ id: z.uuid() })

export function toConversion(row: typeof conversions.$inferSelect): Conversion {
  const { updatedAt: _updatedAt, userId: _userId, ...conversion } = row
  return { ...conversion, createdAt: new Date(conversion.createdAt).toISOString() }
}

export async function listConversions(db: Database, monthId: string) {
  const rows = await db.select().from(conversions).where(eq(conversions.monthId, monthId)).orderBy(asc(conversions.day), asc(conversions.createdAt))
  return rows.map(toConversion)
}

export function conversionRoutes(db: Database, rates: RateService) {
  /**
   * The fee isn't typed in: it is whatever was sent beyond the BRL the received EUR are worth at
   * the month's locked rate, or at the live rate when the month has none. It is worked out when
   * the amounts are saved and kept, since the rate keeps moving afterwards.
   */
  async function feeBrl(month: Pick<typeof months.$inferSelect, 'exchangeRate'>, amounts: { sentBrl: number, receivedEur: number }) {
    return conversionFee(amounts, month.exchangeRate ?? (await rates.get()).rate?.rate ?? null)
  }

  return new Hono<AuthEnv>()
    .get('/months/:year/:month/conversions', validate('param', monthKeySchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      return c.json(await listConversions(db, row.id))
    })
    .post('/months/:year/:month/conversions', validate('param', monthKeySchema), validate('json', createConversionSchema), async (c) => {
      const key = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (input.day > daysInMonth(key.year, key.month))
        return c.json({ error: 'Day is outside the month' }, 400)
      const [conversion] = await db.insert(conversions).values({ ...input, feeBrl: await feeBrl(row, input), monthId: row.id, userId: row.userId }).returning()
      return c.json(toConversion(conversion!), 201)
    })
    .patch('/months/:year/:month/conversions/:id', validate('param', conversionParam), validate('json', updateConversionSchema), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const month = await findMonth(db, c.var.user.id, key)
      if (!month)
        return c.json({ error: 'Month not found' }, 404)
      const [existing] = await db.select().from(conversions).where(and(eq(conversions.id, id), eq(conversions.monthId, month.id))).limit(1)
      if (!existing)
        return c.json({ error: 'Conversion not found' }, 404)
      const input = c.req.valid('json')
      const parsed = createConversionSchema.safeParse({ ...existing, ...input })
      if (!parsed.success)
        return c.json({ error: 'Invalid request', issues: parsed.error.issues }, 400)
      if (parsed.data.day > daysInMonth(key.year, key.month))
        return c.json({ error: 'Day is outside the month' }, 400)
      // Changing only the day or the note keeps the fee from when the amounts were saved.
      const sameAmounts = parsed.data.sentBrl === existing.sentBrl && parsed.data.receivedEur === existing.receivedEur
      const [conversion] = await db.update(conversions).set({ ...parsed.data, feeBrl: sameAmounts ? existing.feeBrl : await feeBrl(month, parsed.data) }).where(eq(conversions.id, id)).returning()
      return c.json(toConversion(conversion!))
    })
    .delete('/months/:year/:month/conversions/:id', validate('param', conversionParam), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const month = await findMonth(db, c.var.user.id, key)
      if (!month)
        return c.json({ error: 'Month not found' }, 404)
      const [conversion] = await db.delete(conversions)
        .where(and(eq(conversions.id, id), eq(conversions.monthId, month.id)))
        .returning({ id: conversions.id })
      if (!conversion)
        return c.json({ error: 'Conversion not found' }, 404)
      return c.body(null, 204)
    })
}
