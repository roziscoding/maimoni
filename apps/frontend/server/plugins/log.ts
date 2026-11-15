import type { LogLevelType } from 'loglayer'
import { consola } from 'consola'

/** Maps consola log types to LogLayer levels; anything missing logs as `info`. */
const LEVELS: Record<string, LogLevelType> = {
  fatal: 'fatal',
  error: 'error',
  fail: 'error',
  warn: 'warn',
  debug: 'debug',
  trace: 'trace',
  verbose: 'trace',
}

/**
 * Routes Nitro's consola output through LogLayer. Nitro's tagged loggers share the root
 * reporters array, so it is mutated in place (`setReporters` would replace it and miss them).
 */
export default defineNitroPlugin(() => {
  consola.removeReporter()
  consola.addReporter({
    log: ({ type, tag, args }) => {
      const error = args.find(arg => arg instanceof Error)
      const message = args.filter(arg => arg !== error).join(' ')
      let entry = tag ? log.withMetadata({ tag }) : log
      if (error)
        entry = entry.withError(error)
      entry[LEVELS[type] ?? 'info'](message || error?.message || '')
    },
  })
})
