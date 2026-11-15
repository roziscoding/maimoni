/**
 * semantic-release plugin for the mobile app (configured in ../.releaserc.json).
 *
 * - analyzeCommits / generateNotes: the stock plugins, fed only the commits that touch the mobile
 *   app, so changes elsewhere in the monorepo don't release it.
 * - verifyRelease: writes the version for each platform to $GITHUB_OUTPUT, so the workflow can
 *   build both apps after a dry run and publish the release in a second run.
 */
import { execFileSync } from 'node:child_process'
import { appendFileSync } from 'node:fs'
import process from 'node:process'
import { analyzeCommits as analyze } from '@semantic-release/commit-analyzer'
import { generateNotes as notes } from '@semantic-release/release-notes-generator'
import { appVersion } from '../../../packages/shared/src/app-version.ts'

interface Commit { hash: string }
interface Context {
  commits?: Commit[]
  nextRelease?: { version: string }
  logger: { log: (message: string, ...args: unknown[]) => void }
}

/** Paths, relative to the repository root, whose changes count as changes to the mobile app. */
const PATHS = ['apps/mobile/', '.mise/tasks/mobile/', '.github/workflows/mobile-', 'packages/shared/src/app-version.ts']

function touchesMobile({ hash }: Commit) {
  const files = execFileSync('git', ['diff-tree', '--no-commit-id', '--name-only', '-r', '--root', hash], { encoding: 'utf8' })
  return files.split('\n').some(file => PATHS.some(path => file.startsWith(path)))
}

function onlyMobile(context: Context): Context {
  return { ...context, commits: (context.commits ?? []).filter(touchesMobile) }
}

export function analyzeCommits(config: object, context: Context) {
  return analyze(config, onlyMobile(context))
}

export function generateNotes(config: object, context: Context) {
  return notes(config, onlyMobile(context))
}

export function verifyRelease(_config: object, { nextRelease, logger }: Context) {
  // Throws for versions the build numbers can't represent, before anything is built or tagged.
  const { version, iosVersion, code } = appVersion(nextRelease!.version)
  logger.log('Android %s, iOS %s, build number %d', version, iosVersion, code)
  if (process.env.GITHUB_OUTPUT)
    appendFileSync(process.env.GITHUB_OUTPUT, `version=${version}\nios_version=${iosVersion}\ncode=${code}\n`)
}
