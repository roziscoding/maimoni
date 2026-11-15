import process from 'node:process'
import { PinoTransport } from '@loglayer/transport-pino'
import { getPrettyTerminal } from '@loglayer/transport-pretty-terminal'
import Database from 'bun:sqlite'
import { LogLayer } from 'loglayer'
import pino from 'pino'
import { serializeError } from 'serialize-error'

export const log = new LogLayer({
  errorSerializer: serializeError,
  transport: [
    new PinoTransport({
      logger: pino(),
      enabled: !process.stdin.isTTY,
    }),
    getPrettyTerminal({
      enabled: !!process.stdin.isTTY,
      database: new Database(':memory:'),
    }),
  ],
})
