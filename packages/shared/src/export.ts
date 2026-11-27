import { z } from 'zod'
import { dailySpendSchema, monthItemSchema, monthSchema, templateItemSchema, userCurrencySchema } from './schemas'

/**
 * Everything a person keeps, as one file: what `GET /api/data/export` answers and what the mobile
 * app's local mode exports and imports. Ids and links between items are kept, so the file can be
 * loaded into either storage as it is.
 *
 * Changing the shape takes a new `version`, and every reader has to keep accepting the old ones.
 */
export const dataExportSchema = z.object({
  format: z.literal('maimoni-export'),
  version: z.literal(1),
  exportedAt: z.iso.datetime(),
  currencies: z.array(userCurrencySchema.omit({ inUse: true })),
  template: z.array(templateItemSchema),
  months: z.array(monthSchema.extend({
    items: z.array(monthItemSchema),
    spends: z.array(dailySpendSchema),
  })),
})
export type DataExport = z.infer<typeof dataExportSchema>
