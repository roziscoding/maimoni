import type { MonthListEntry, SessionEntry, TemplateDetail } from '@maimoni/shared'
import { describe, expect, test } from 'bun:test'
import { createTestUser, login, setup, signIn, testPassword } from './setup'

/** Waits for something that happens after a response, such as the password reset email. */
async function until(condition: () => boolean) {
  const deadline = Date.now() + 5000
  while (!condition()) {
    if (Date.now() > deadline)
      throw new Error('timed out waiting')
    await Bun.sleep(5)
  }
}

describe('auth', () => {
  test('protects the API but leaves health and auth endpoints open', async () => {
    const { as } = await setup()
    const anonymous = as(null)
    expect((await anonymous('GET', '/health')).status).toBe(200)
    expect((await anonymous('GET', '/months')).status).toBe(401)
    expect((await anonymous('GET', '/template')).status).toBe(401)
    expect((await anonymous('GET', '/auth/get-session')).status).toBe(200)
  })

  test('lists the social providers that have credentials', async () => {
    const { as } = await setup()
    expect((await as(null)('GET', '/sign-in-providers')).body).toEqual([])
    const configured = await setup(6, { GOOGLE_CLIENT_ID: 'id', GOOGLE_CLIENT_SECRET: 'secret' })
    expect((await configured.as(null)('GET', '/sign-in-providers')).body).toEqual(['google'])
  })

  test('GOOGLE_IOS_CLIENT_ID is accepted as a second Google audience', async () => {
    const google = async (env: Record<string, string>) =>
      (await (await setup(6, env)).auth.$context).socialProviders.find(provider => provider.id === 'google')?.options?.clientId
    expect(await google({ GOOGLE_CLIENT_ID: 'web', GOOGLE_CLIENT_SECRET: 'secret' })).toBe('web')
    expect(await google({ GOOGLE_CLIENT_ID: 'web', GOOGLE_CLIENT_SECRET: 'secret', GOOGLE_IOS_CLIENT_ID: 'ios' })).toEqual(['web', 'ios'])
  })

  test('the passkey plugin accepts the Android app\'s origins', async () => {
    const fingerprint = 'FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C'
    const { auth } = await setup(6, { ANDROID_APP_PACKAGE: 'ninja.roz.maimoni', ANDROID_APP_CERT_SHA256: fingerprint })
    const passkey = auth.options.plugins?.find(plugin => plugin.id === 'passkey') as { options?: { origin?: unknown } } | undefined
    expect(passkey?.options?.origin).toEqual(['http://localhost:3000', 'android:apk-key-hash:-sYXRdwJA3hvue3mKpYrOZ9zSPC7b4mbgzJmdZEDO5w'])
  })

  test('AUTH_TRUSTED_PROXIES sets the proxies whose X-Forwarded-For is trusted', async () => {
    expect((await setup()).auth.options.advanced?.ipAddress?.trustedProxies).toEqual([])
    const { auth } = await setup(6, { AUTH_TRUSTED_PROXIES: '10.0.1.2, 172.18.0.0/16' })
    expect(auth.options.advanced?.ipAddress?.trustedProxies).toEqual(['10.0.1.2', '172.18.0.0/16'])
  })

  test('sign up is disabled by default', async () => {
    const { as } = await setup()
    const response = await as(null)('POST', '/auth/sign-up/email', { email: 'new@example.com', password: testPassword, name: 'New' })
    expect(response.status).toBeGreaterThanOrEqual(400)
    expect((await as(null)('POST', '/auth/sign-in/email', { email: 'new@example.com', password: testPassword })).status).toBe(401)
  })

  test('AUTH_SIGNUP_ENABLED=true allows sign up', async () => {
    const { as } = await setup(6, { AUTH_SIGNUP_ENABLED: 'true' })
    const response = await as(null)('POST', '/auth/sign-up/email', { email: 'new@example.com', password: testPassword, name: 'New' })
    expect(response.status).toBe(200)
    expect((await as(null)('POST', '/auth/sign-in/email', { email: 'new@example.com', password: testPassword })).status).toBe(200)
  })

  test('keeps each user\'s data apart', async () => {
    const { app, auth, as, request } = await setup(6, {}, { enablePurge: true })
    await request('POST', '/template/items', { name: 'Aluguel', currency: 'EUR', amount: 1000 })
    await request('POST', '/months', { year: 2026, month: 10 })
    await request('POST', '/months/2026/10/spends', { day: 1, amount: 10 })

    const { body: mine } = await request<MonthListEntry[]>('GET', '/months')
    expect(mine[0]).not.toHaveProperty('userId')
    const { body: detail } = await request('GET', '/months/2026/10')
    expect(detail.items[0]).not.toHaveProperty('userId')
    expect(detail.spends[0]).not.toHaveProperty('userId')

    const other = as(await signIn(app, auth, 'other@example.com'))
    expect((await other<MonthListEntry[]>('GET', '/months')).body).toEqual([])
    expect((await other('GET', '/months/2026/10')).status).toBe(404)
    const { body: template } = await other<TemplateDetail>('GET', '/template')
    expect(template.items).toEqual([])

    // Same month key is free for another user, and clearing their data leaves the first user's alone.
    expect((await other('POST', '/months', { year: 2026, month: 10 })).status).toBe(201)
    expect((await other('DELETE', '/data')).status).toBe(204)
    expect((await request<MonthListEntry[]>('GET', '/months')).body).toHaveLength(1)
  })

  test('a password reset request answers 204 and only emails existing users', async () => {
    const { as, mails } = await setup()
    const anonymous = as(null)
    expect((await anonymous('POST', '/password-reset', { email: 'nobody@example.com' })).status).toBe(204)
    expect((await anonymous('POST', '/password-reset', { email: 'owner@example.com' })).status).toBe(204)
    // The email is sent after the response.
    await until(() => mails.length > 0)
    expect(mails.map(mail => mail.to)).toEqual(['owner@example.com'])
    expect((await anonymous('POST', '/password-reset', { email: 'not an email' })).status).toBe(400)
  })

  test('the emailed link sets a new password', async () => {
    const { app, as, mails } = await setup()
    const anonymous = as(null)
    await anonymous('POST', '/password-reset', { email: 'owner@example.com' })
    await until(() => mails.length > 0)
    const link = new URL(mails[0]!.text.match(/https?:\S+/)![0])
    expect(link.origin).toBe('http://localhost:3000')

    // The link goes through the backend, which redirects to the frontend page with the token.
    const redirect = await app.request(`${link.pathname}${link.search}`)
    expect(redirect.status).toBe(302)
    const landing = new URL(redirect.headers.get('location')!, link.origin)
    expect(landing.pathname).toBe('/reset-password')
    const token = landing.searchParams.get('token')

    const newPassword = 'a brand new password'
    expect((await anonymous('POST', '/auth/reset-password', { newPassword, token })).status).toBe(200)
    expect((await anonymous('POST', '/auth/sign-in/email', { email: 'owner@example.com', password: testPassword })).status).toBe(401)
    expect((await anonymous('POST', '/auth/sign-in/email', { email: 'owner@example.com', password: newPassword })).status).toBe(200)
    // One use only.
    expect((await anonymous('POST', '/auth/reset-password', { newPassword, token })).status).toBe(400)
  })

  test('accepts a bearer token from sign in', async () => {
    const { app, auth, as } = await setup()
    await createTestUser(auth, 'mobile@example.com')
    const token = (await login(app, 'mobile@example.com')).headers.get('set-auth-token')
    expect(token).toBeTruthy()
    expect((await as({ authorization: `Bearer ${token}` })('GET', '/months')).status).toBe(200)
  })

  test('lists the user\'s sessions and ends the others', async () => {
    const { app, auth, as } = await setup()
    await createTestUser(auth, 'mobile@example.com')
    const session = async () => as({ authorization: `Bearer ${(await login(app, 'mobile@example.com')).headers.get('set-auth-token')}` })
    const [first, second, third] = [await session(), await session(), await session()]

    const { body: list } = await first<SessionEntry[]>('GET', '/sessions')
    expect(list).toHaveLength(3)
    expect(list.map(entry => entry.current)).toEqual([true, false, false])
    expect(list[0]).not.toHaveProperty('token')

    // Another user's sessions are out of reach, and the current one ends by signing out.
    const other = as(await signIn(app, auth, 'other@example.com'))
    expect((await other('DELETE', `/sessions/${list[1]!.id}`)).status).toBe(404)
    expect((await first('DELETE', `/sessions/${list[0]!.id}`)).status).toBe(400)

    const secondId = (await second<SessionEntry[]>('GET', '/sessions')).body[0]!.id
    expect((await first('DELETE', `/sessions/${secondId}`)).status).toBe(204)
    expect((await second('GET', '/months')).status).toBe(401)
    expect((await third('GET', '/months')).status).toBe(200)

    expect((await first('DELETE', '/sessions')).status).toBe(204)
    expect((await third('GET', '/months')).status).toBe(401)
    expect((await first<SessionEntry[]>('GET', '/sessions')).body).toHaveLength(1)
    expect((await other('GET', '/months')).status).toBe(200)

    // A bearer client ends its own session, and the token stops working.
    expect((await first('DELETE', '/sessions/current')).status).toBe(204)
    expect((await first('GET', '/months')).status).toBe(401)
    expect((await first('DELETE', '/sessions/current')).status).toBe(401)
  })

  test('ending the current session reports a failure to delete it', async () => {
    const { app, auth, as } = await setup()
    await createTestUser(auth, 'mobile@example.com')
    const session = as({ authorization: `Bearer ${(await login(app, 'mobile@example.com')).headers.get('set-auth-token')}` })
    const { internalAdapter } = await auth.$context
    const deleteSession = internalAdapter.deleteSession
    internalAdapter.deleteSession = async () => {
      throw new Error('database is down')
    }
    expect((await session('DELETE', '/sessions/current')).status).toBe(500)
    internalAdapter.deleteSession = deleteSession
    expect((await session('GET', '/months')).status).toBe(200)
  })

  test('each sign in is its own session', async () => {
    const { app, auth, as } = await setup()
    await createTestUser(auth, 'mobile@example.com')
    const first = (await login(app, 'mobile@example.com')).headers.get('set-auth-token')
    const second = (await login(app, 'mobile@example.com')).headers.get('set-auth-token')
    expect(first).not.toBe(second)
    expect((await as({ authorization: `Bearer ${first}` })('GET', '/months')).status).toBe(200)
    expect((await as({ authorization: `Bearer ${second}` })('GET', '/months')).status).toBe(200)
    expect((await as({ authorization: `Bearer ${first}` })('POST', '/auth/sign-out')).status).toBe(200)
    expect((await as({ authorization: `Bearer ${first}` })('GET', '/months')).status).toBe(401)
    expect((await as({ authorization: `Bearer ${second}` })('GET', '/months')).status).toBe(200)
  })
})
