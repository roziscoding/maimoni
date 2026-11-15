import type { ValidationTargets } from 'hono'
import type { ZodType } from 'zod'
import { zValidator } from '@hono/zod-validator'

/** zValidator that answers with the API's `{ error, issues }` shape. */
export function validate<Target extends keyof ValidationTargets, Schema extends ZodType>(target: Target, schema: Schema) {
  return zValidator(target, schema, (result, c) => {
    if (!result.success)
      return c.json({ error: 'Invalid request', issues: result.error.issues }, 400)
  })
}
