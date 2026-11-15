import type { PgDatabase, PgQueryResultHKT } from 'drizzle-orm/pg-core'
import process from 'node:process'
import { drizzle } from 'drizzle-orm/bun-sql'
import * as schema from './schema'

/** Driver-agnostic handle so tests can run the same code against PGlite. */
export type Database = PgDatabase<PgQueryResultHKT, typeof schema>

export function connect(url = process.env.DATABASE_URL) {
  if (!url)
    throw new Error('DATABASE_URL is not set')
  return drizzle({ connection: url, schema })
}

export { schema }
