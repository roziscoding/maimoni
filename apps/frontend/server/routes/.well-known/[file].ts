const FILES = new Set(['assetlinks.json', 'apple-app-site-association'])

/**
 * Android and iOS read these two files from the root of the domain to tie the mobile app to it
 * (passkeys). The backend builds them from its environment.
 */
export default defineEventHandler((event) => {
  const file = getRouterParam(event, 'file') ?? ''
  if (!FILES.has(file))
    throw createError({ statusCode: 404, statusMessage: 'Not found' })
  const { apiBase } = useRuntimeConfig(event)
  return proxyRequest(event, `${apiBase.replace(/\/$/, '')}/api/well-known/${file}`)
})
