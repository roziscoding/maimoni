import type { Month, MonthDetail, MonthItem, MonthKey, MonthListEntry } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import type { RateService } from '../services/rates'
import { createMonthItemSchema, createMonthSchema, monthKeySchema, reorderSchema, summarizeMonth, updateMonthItemSchema, updateMonthSchema } from '@maimoni/shared'
import { and, asc, desc, eq, inArray, lt, max, or, sql } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { dailySpends, monthItems, months, templateItems } from '../db/schema'
import { validate } from '../lib/validate'
import { CURRENCY_NOT_ADDED, mainCurrencyOf, userHasCurrency } from './currencies'
import { listSpends, toDailySpend } from './spends'
import { listTemplateItems, toTemplateItem } from './template'

const itemParam = monthKeySchema.extend({ id: z.uuid() })

function toMonth(row: typeof months.$inferSelect): Month {
  const { updatedAt: _updatedAt, userId: _userId, ...month } = row
  return { ...month, createdAt: new Date(month.createdAt).toISOString() }
}

function toMonthItem(row: typeof monthItems.$inferSelect): MonthItem {
  const { createdAt: _createdAt, updatedAt: _updatedAt, userId: _userId, ...item } = row
  return item
}

export async function findMonth(db: Database, userId: string, { year, month }: MonthKey) {
  const [row] = await db.select().from(months).where(and(eq(months.userId, userId), eq(months.year, year), eq(months.month, month))).limit(1)
  return row
}

async function listItems(db: Database, monthId: string) {
  const rows = await db.select().from(monthItems).where(eq(monthItems.monthId, monthId)).orderBy(asc(monthItems.position), asc(monthItems.createdAt))
  return rows.map(toMonthItem)
}

/** Builds the new month's items from the template or from the closest earlier month. */
async function seedItems(db: Database, userId: string, { year, month }: MonthKey, source: 'template' | 'previous') {
  const template = await listTemplateItems(db, userId)
  if (source === 'template') {
    return template.map(item => ({
      templateItemId: item.id,
      name: item.name,
      currency: item.currency,
      kind: item.kind,
      amount: item.amount,
      expression: item.expression,
      needsReview: item.variable,
      position: item.position,
    }))
  }

  const [previous] = await db.select().from(months).where(and(eq(months.userId, userId), or(lt(months.year, year), and(eq(months.year, year), lt(months.month, month))))).orderBy(desc(months.year), desc(months.month)).limit(1)
  if (!previous)
    return null
  const variable = new Set(template.filter(item => item.variable).map(item => item.id))
  const items = await listItems(db, previous.id)
  return items.map(item => ({
    templateItemId: item.templateItemId,
    name: item.name,
    currency: item.currency,
    kind: item.kind,
    amount: item.amount,
    expression: item.expression,
    needsReview: item.templateItemId !== null && variable.has(item.templateItemId),
    position: item.position,
  }))
}

export function monthRoutes(db: Database, rates: RateService) {
  async function detail(row: typeof months.$inferSelect): Promise<MonthDetail> {
    const [items, spends, rateResult] = await Promise.all([listItems(db, row.id), listSpends(db, row.id), rates.get(row.mainCurrency)])
    const month = toMonth(row)
    const summary = summarizeMonth(month, items, { rates: rateResult.rates?.rates ?? null, spends })
    return { month, items, spends, summary, rates: rateResult.rates, rateError: rateResult.error }
  }

  return new Hono<AuthEnv>()
    .get('/months', async (c) => {
      const userId = c.var.user.id
      const [rows, items, spends] = await Promise.all([
        db.select().from(months).where(eq(months.userId, userId)).orderBy(desc(months.year), desc(months.month)),
        db.select().from(monthItems).where(eq(monthItems.userId, userId)).orderBy(asc(monthItems.position)),
        db.select().from(dailySpends).where(eq(dailySpends.userId, userId)),
      ])
      // Months made under different main currencies are quoted against different ones.
      const liveRates = new Map(await Promise.all([...new Set(rows.map(row => row.mainCurrency))].map(async base => [base, (await rates.get(base)).rates?.rates ?? null] as const)))
      const itemsByMonth = Map.groupBy(items.map(toMonthItem), item => item.monthId)
      const spendsByMonth = Map.groupBy(spends.map(toDailySpend), spend => spend.monthId)
      const body: MonthListEntry[] = rows.map((row) => {
        const month = toMonth(row)
        const summary = summarizeMonth(month, itemsByMonth.get(month.id) ?? [], { rates: liveRates.get(month.mainCurrency) ?? null, spends: spendsByMonth.get(month.id) ?? [] })
        return { ...month, summary }
      })
      return c.json(body)
    })
    .post('/months', validate('json', createMonthSchema), async (c) => {
      const userId = c.var.user.id
      const { source, ...key } = c.req.valid('json')
      if (await findMonth(db, userId, key))
        return c.json({ error: 'Month already exists' }, 409)
      const items = await seedItems(db, userId, key, source)
      if (!items)
        return c.json({ error: 'There is no earlier month to copy from' }, 400)
      // The month keeps this currency: changing the main one later doesn't move it.
      const mainCurrency = await mainCurrencyOf(db, userId)
      if (!mainCurrency)
        return c.json({ error: 'Add a currency before creating a month' }, 409)
      const row = await db.transaction(async (tx) => {
        const [created] = await tx.insert(months).values({ ...key, userId, mainCurrency }).returning()
        if (items.length)
          await tx.insert(monthItems).values(items.map(item => ({ ...item, monthId: created!.id, userId })))
        return created!
      })
      return c.json(await detail(row), 201)
    })
    .get('/months/:year/:month', validate('param', monthKeySchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      return c.json(await detail(row))
    })
    .patch('/months/:year/:month', validate('param', monthKeySchema), validate('json', updateMonthSchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (!Object.keys(input).length)
        return c.json(await detail(row))
      const [updated] = await db.update(months).set(input).where(eq(months.id, row.id)).returning()
      return c.json(await detail(updated!))
    })
    .delete('/months/:year/:month', validate('param', monthKeySchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      await db.delete(months).where(eq(months.id, row.id))
      return c.body(null, 204)
    })
    .post('/months/:year/:month/items', validate('param', monthKeySchema), validate('json', createMonthItemSchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (!await userHasCurrency(db, row.userId, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      const [last] = await db.select({ value: max(monthItems.position) }).from(monthItems).where(eq(monthItems.monthId, row.id))
      const [item] = await db.insert(monthItems)
        .values({ ...input, monthId: row.id, userId: row.userId, position: (last?.value ?? -1) + 1 })
        .returning()
      return c.json(toMonthItem(item!), 201)
    })
    .put('/months/:year/:month/items/order', validate('param', monthKeySchema), validate('json', reorderSchema), async (c) => {
      const row = await findMonth(db, c.var.user.id, c.req.valid('param'))
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const { ids } = c.req.valid('json')
      const existing = await db.select({ id: monthItems.id }).from(monthItems).where(and(eq(monthItems.monthId, row.id), inArray(monthItems.id, ids)))
      if (existing.length !== new Set(ids).size)
        return c.json({ error: 'Unknown item in order' }, 400)
      await db.transaction(async (tx) => {
        for (const [position, id] of ids.entries())
          await tx.update(monthItems).set({ position }).where(eq(monthItems.id, id))
      })
      return c.json(await listItems(db, row.id))
    })
    .patch('/months/:year/:month/items/:id', validate('param', itemParam), validate('json', updateMonthItemSchema), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const input = c.req.valid('json')
      if (input.currency && !await userHasCurrency(db, row.userId, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      const amountChanged = input.amount !== undefined
      const [item] = await db.update(monthItems)
        .set({
          ...input,
          // Typing a value confirms it, and a plain amount replaces any previous expression.
          needsReview: amountChanged && input.needsReview === undefined ? false : input.needsReview,
          expression: amountChanged && input.expression === undefined ? null : input.expression,
        })
        .where(and(eq(monthItems.id, id), eq(monthItems.monthId, row.id)))
        .returning()
      if (!item)
        return c.json({ error: 'Item not found' }, 404)
      return c.json(toMonthItem(item))
    })
    .delete('/months/:year/:month/items/:id', validate('param', itemParam), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const [item] = await db.delete(monthItems)
        .where(and(eq(monthItems.id, id), eq(monthItems.monthId, row.id)))
        .returning({ id: monthItems.id })
      if (!item)
        return c.json({ error: 'Item not found' }, 404)
      return c.body(null, 204)
    })
    .post('/months/:year/:month/items/:id/promote', validate('param', itemParam), async (c) => {
      const { id, ...key } = c.req.valid('param')
      const row = await findMonth(db, c.var.user.id, key)
      if (!row)
        return c.json({ error: 'Month not found' }, 404)
      const template = await db.transaction(async (tx) => {
        // Row lock: a double click must update the template item the first request created, not add a second one.
        const [item] = await tx.select().from(monthItems).where(and(eq(monthItems.id, id), eq(monthItems.monthId, row.id))).for('update')
        if (!item)
          return null
        const values = { name: item.name, currency: item.currency, kind: item.kind, amount: item.amount, expression: item.expression }
        if (item.templateItemId) {
          const [updated] = await tx.update(templateItems).set(values).where(and(eq(templateItems.id, item.templateItemId), eq(templateItems.userId, row.userId))).returning()
          if (updated)
            return updated
        }
        const [created] = await tx.insert(templateItems)
          .values({ ...values, userId: row.userId, position: sql`(select coalesce(max(${templateItems.position}), -1) + 1 from ${templateItems} where ${templateItems.userId} = ${row.userId})` })
          .returning()
        await tx.update(monthItems).set({ templateItemId: created!.id }).where(eq(monthItems.id, item.id))
        return created!
      })
      if (!template)
        return c.json({ error: 'Item not found' }, 404)
      return c.json(toTemplateItem(template))
    })
}
