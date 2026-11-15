import type { MonthListEntry, TemplateDetail } from '@maimoni/shared'
import { describe, expect, test } from 'bun:test'
import { createTestUser, login, setup, signIn, testPassword } from './setup'

describe('auth', () => {
  test('protects the API but leaves health and auth endpoints open', async () => {
    const { as } = await setup()
    const anonymous = as(null)
    expect((await anonymous('GET', '/health')).status).toBe(200)
    expect((await anonymous('GET', '/months')).status).toBe(401)
    expect((await anonymous('GET', '/template')).status).toBe(401)
    expect((await anonymous('GET', '/auth/get-session')).status).toBe(200)
  })

  test('sign up is disabled by default', async () => {
    const { as } = await setup()
    const response = await as(null)('POST', '/auth/sign-up/email', { email: 'new@example.com', password: testPassword, name: 'New' })
    expect(response.status).toBeGreaterThanOrEqual(400)
    expect((await as(null)('POST', '/auth/sign-in/email', { email: 'new@example.com', password: testPassword })).status).toBe(401)
  })

  test('AUTH_SIGNUP_ENABLED=true allows sign up', async () => {
    const { as } = await setup(6, true, { AUTH_SIGNUP_ENABLED: 'true' })
    const response = await as(null)('POST', '/auth/sign-up/email', { email: 'new@example.com', password: testPassword, name: 'New' })
    expect(response.status).toBe(200)
    expect((await as(null)('POST', '/auth/sign-in/email', { email: 'new@example.com', password: testPassword })).status).toBe(200)
  })

  test('keeps each user\'s data apart', async () => {
    const { app, auth, as, request } = await setup()
    await request('POST', '/template/items', { name: 'Aluguel', currency: 'EUR', amount: 1000 })
    await request('POST', '/months', { year: 2026, month: 10 })
    await request('PATCH', '/settings', { wiseFee: 0.05 })
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
    expect(template.settings.wiseFee).toBe(0.039)

    // Same month key is free for another user, and clearing their data leaves the first user's alone.
    expect((await other('POST', '/months', { year: 2026, month: 10 })).status).toBe(201)
    expect((await other('DELETE', '/data')).status).toBe(204)
    expect((await request<MonthListEntry[]>('GET', '/months')).body).toHaveLength(1)
  })

  test('accepts a bearer token from sign in', async () => {
    const { app, auth, as } = await setup()
    await createTestUser(auth, 'mobile@example.com')
    const token = (await login(app, 'mobile@example.com')).headers.get('set-auth-token')
    expect(token).toBeTruthy()
    expect((await as({ authorization: `Bearer ${token}` })('GET', '/months')).status).toBe(200)
  })
})
