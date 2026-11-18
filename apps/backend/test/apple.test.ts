import { Buffer } from 'node:buffer'
import { describe, expect, test } from 'bun:test'
import { APPLE_CLIENT_SECRET_TTL_SECONDS, appleClientSecret } from '../src/lib/apple'
import { setup } from './setup'

/** A fresh P-256 key pair, with the private half as the PEM text of a `.p8` file. */
async function appleKey() {
  const { privateKey, publicKey } = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify'])
  const body = Buffer.from(await crypto.subtle.exportKey('pkcs8', privateKey)).toString('base64').match(/.{1,64}/g)!.join('\n')
  return { pem: `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----\n`, publicKey }
}

function decode(part: string) {
  return JSON.parse(Buffer.from(part, 'base64url').toString())
}

describe('Apple client secret', () => {
  test('is a JWT signed with the key, valid for 180 days', async () => {
    const { pem, publicKey } = await appleKey()
    const now = new Date('2026-11-15T12:00:00Z')
    const secret = await appleClientSecret({ teamId: 'TEAM123456', keyId: 'KEY1234567', clientId: 'ninja.roz.maimoni.web', privateKey: pem, now })

    const [header, claims, signature] = secret.split('.') as [string, string, string]
    expect(decode(header)).toEqual({ alg: 'ES256', kid: 'KEY1234567' })
    const issuedAt = now.getTime() / 1000
    expect(decode(claims)).toEqual({
      iss: 'TEAM123456',
      iat: issuedAt,
      exp: issuedAt + APPLE_CLIENT_SECRET_TTL_SECONDS,
      aud: 'https://appleid.apple.com',
      sub: 'ninja.roz.maimoni.web',
    })
    const valid = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${header}.${claims}`))
    expect(valid).toBe(true)
  })

  test('accepts the key on one line with \\n escapes, as in an env file', async () => {
    const { pem } = await appleKey()
    const secret = await appleClientSecret({ teamId: 'T', keyId: 'K', clientId: 'C', privateKey: pem.trim().replaceAll('\n', '\\n') })
    expect(secret.split('.')).toHaveLength(3)
  })

  test('enables Apple sign in only with a usable key', async () => {
    const { pem } = await appleKey()
    const env = { APPLE_CLIENT_ID: 'ninja.roz.maimoni.web', APPLE_TEAM_ID: 'TEAM123456', APPLE_KEY_ID: 'KEY1234567' }
    const working = await setup(6, { ...env, APPLE_PRIVATE_KEY: pem })
    expect((await working.as(null)('GET', '/sign-in-providers')).body).toEqual(['apple'])
    const broken = await setup(6, { ...env, APPLE_PRIVATE_KEY: 'not a key' })
    expect((await broken.as(null)('GET', '/sign-in-providers')).body).toEqual([])
    const incomplete = await setup(6, { APPLE_CLIENT_ID: env.APPLE_CLIENT_ID })
    expect((await incomplete.as(null)('GET', '/sign-in-providers')).body).toEqual([])
  })
})
