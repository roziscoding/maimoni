import type { TemplateDetail, TemplateItem } from '@maimoni/shared'
import type { AuthEnv } from '../auth'
import type { Database } from '../db'
import { createTemplateItemSchema, reorderSchema, updateTemplateItemSchema } from '@maimoni/shared'
import { and, asc, eq, inArray, max } from 'drizzle-orm'
import { Hono } from 'hono'
import { z } from 'zod'
import { templateItems } from '../db/schema'
import { validate } from '../lib/validate'
import { CURRENCY_NOT_ADDED, userHasCurrency } from './currencies'

const idParam = z.object({ id: z.uuid() })

export function toTemplateItem(row: typeof templateItems.$inferSelect): TemplateItem {
  const { createdAt: _createdAt, updatedAt: _updatedAt, userId: _userId, ...item } = row
  return item
}

export async function listTemplateItems(db: Database, userId: string) {
  const rows = await db.select().from(templateItems).where(eq(templateItems.userId, userId)).orderBy(asc(templateItems.position), asc(templateItems.createdAt))
  return rows.map(toTemplateItem)
}

export async function nextTemplatePosition(db: Database, userId: string) {
  const [row] = await db.select({ value: max(templateItems.position) }).from(templateItems).where(eq(templateItems.userId, userId))
  return (row?.value ?? -1) + 1
}

export function templateRoutes(db: Database) {
  return new Hono<AuthEnv>()
    .get('/template', async (c) => {
      const userId = c.var.user.id
      const body: TemplateDetail = { items: await listTemplateItems(db, userId) }
      return c.json(body)
    })
    .post('/template/items', validate('json', createTemplateItemSchema), async (c) => {
      const userId = c.var.user.id
      const input = c.req.valid('json')
      if (!await userHasCurrency(db, userId, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      const [row] = await db.insert(templateItems).values({ ...input, userId, position: await nextTemplatePosition(db, userId) }).returning()
      return c.json(toTemplateItem(row!), 201)
    })
    .put('/template/items/order', validate('json', reorderSchema), async (c) => {
      const userId = c.var.user.id
      const { ids } = c.req.valid('json')
      const existing = await db.select({ id: templateItems.id }).from(templateItems).where(and(eq(templateItems.userId, userId), inArray(templateItems.id, ids)))
      if (existing.length !== new Set(ids).size)
        return c.json({ error: 'Unknown template item in order' }, 400)
      await db.transaction(async (tx) => {
        for (const [position, id] of ids.entries())
          await tx.update(templateItems).set({ position }).where(and(eq(templateItems.id, id), eq(templateItems.userId, userId)))
      })
      return c.json(await listTemplateItems(db, userId))
    })
    .patch('/template/items/:id', validate('param', idParam), validate('json', updateTemplateItemSchema), async (c) => {
      const { id } = c.req.valid('param')
      const input = c.req.valid('json')
      if (input.currency && !await userHasCurrency(db, c.var.user.id, input.currency))
        return c.json(CURRENCY_NOT_ADDED, 400)
      // A plain amount replaces whatever expression produced the previous one.
      const expression = input.amount !== undefined && input.expression === undefined ? null : input.expression
      const [row] = await db.update(templateItems).set({ ...input, expression }).where(and(eq(templateItems.id, id), eq(templateItems.userId, c.var.user.id))).returning()
      if (!row)
        return c.json({ error: 'Template item not found' }, 404)
      return c.json(toTemplateItem(row))
    })
    .delete('/template/items/:id', validate('param', idParam), async (c) => {
      const { id } = c.req.valid('param')
      const [row] = await db.delete(templateItems).where(and(eq(templateItems.id, id), eq(templateItems.userId, c.var.user.id))).returning({ id: templateItems.id })
      if (!row)
        return c.json({ error: 'Template item not found' }, 404)
      return c.body(null, 204)
    })
}
