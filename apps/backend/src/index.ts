import process from 'node:process'
import { createApp } from './app'
import { createAuth } from './auth'
import { connect } from './db'
import { log } from './lib/log'
import { createAppReleaseService } from './services/app-releases'
import { createRateService } from './services/rates'
import { createWiseService } from './services/wise'

const db = connect()
const appReleases = createAppReleaseService({ token: process.env.GITHUB_RELEASES_TOKEN, repository: process.env.GITHUB_RELEASES_REPOSITORY })
const app = createApp({ db, auth: createAuth({ db }), rates: createRateService({ db }), wise: createWiseService(), appReleases })
const port = Number(process.env.PORT ?? 3001)

const server = Bun.serve({ port, fetch: app.fetch })

log.withContext({ port, host: server.hostname }).info(`maimoni backend listening`)
