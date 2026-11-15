import process from 'node:process'
import { drizzle } from 'drizzle-orm/bun-sql'
import { migrate } from 'drizzle-orm/bun-sql/migrator'
import { log } from '../lib/log'

export const migrationsFolder = new URL('../../drizzle', import.meta.url).pathname

export async function runMigrations(url = process.env.DATABASE_URL) {
  if (!url)
    throw new Error('DATABASE_URL is not set')
  const db = drizzle({ connection: url })
  await migrate(db, { migrationsFolder })
  await db.$client.close()
}

if (import.meta.main) {
  await runMigrations()
  log.info('migrations applied')
}
