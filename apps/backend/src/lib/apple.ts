import { Buffer } from 'node:buffer'

export interface AppleClientSecretOptions {
  /** Apple Developer team ID. */
  teamId: string
  /** ID of the Sign in with Apple key. */
  keyId: string
  /** Services ID the secret is for. */
  clientId: string
  /** The key's `.p8` file: PEM text, with real line breaks or `\n` escapes. */
  privateKey: string
  now?: Date
}

/** Apple accepts client secrets that live up to six months. */
export const APPLE_CLIENT_SECRET_TTL_SECONDS = 180 * 24 * 60 * 60

function base64url(data: Uint8Array | string) {
  return Buffer.from(data).toString('base64url')
}

/**
 * Apple has no static client secret: it is a JWT signed with the key from the developer portal.
 * https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret
 */
export async function appleClientSecret({ teamId, keyId, clientId, privateKey, now = new Date() }: AppleClientSecretOptions) {
  const der = Buffer.from(privateKey.replaceAll('\\n', '\n').replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, ''), 'base64')
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const issuedAt = Math.floor(now.getTime() / 1000)
  const header = { alg: 'ES256', kid: keyId }
  const claims = { iss: teamId, iat: issuedAt, exp: issuedAt + APPLE_CLIENT_SECRET_TTL_SECONDS, aud: 'https://appleid.apple.com', sub: clientId }
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`
  // WebCrypto's ECDSA signature is already the raw r||s pair that JWS expects.
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(unsigned))
  return `${unsigned}.${base64url(new Uint8Array(signature))}`
}
