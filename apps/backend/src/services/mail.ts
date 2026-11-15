import { log } from '../lib/log'

export interface Mail {
  to: string
  subject: string
  text: string
  html: string
}

export interface MailServiceOptions {
  /** Resend API key. Without one nothing is sent. */
  apiKey?: string
  /** Sender, e.g. `maimoni <no-reply@example.com>`; its domain has to be verified in Resend. */
  from?: string
  fetch?: typeof fetch
}

export interface MailService {
  /** Sends one email. Failures are logged, never thrown. */
  send: (mail: Mail) => Promise<void>
}

/** Resend's shared sender: needs no verified domain, but only delivers to the Resend account's own address. */
const DEFAULT_FROM = 'maimoni <onboarding@resend.dev>'

/** Sends email through Resend's API. */
export function createMailService({ apiKey, from, fetch: fetcher = fetch }: MailServiceOptions = {}): MailService {
  return {
    async send({ to, subject, text, html }) {
      if (!apiKey) {
        log.warn('RESEND_API_KEY is not set, email not sent')
        return
      }
      try {
        const response = await fetcher('https://api.resend.com/emails', {
          method: 'POST',
          headers: { 'authorization': `Bearer ${apiKey}`, 'content-type': 'application/json' },
          body: JSON.stringify({ from: from || DEFAULT_FROM, to: [to], subject, text, html }),
          signal: AbortSignal.timeout(10_000),
        })
        if (!response.ok)
          throw new Error(`HTTP ${response.status}: ${await response.text()}`)
      }
      catch (error) {
        log.withError(error).error('sending email failed')
      }
    },
  }
}
