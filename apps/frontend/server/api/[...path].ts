/**
 * Forwards every `/api/**` request (method, headers, body, query) to the backend. Redirects are
 * passed on rather than followed, so APK downloads go straight from GitHub to the app.
 */
export default defineEventHandler((event) => {
  const { apiBase } = useRuntimeConfig(event)
  return proxyRequest(event, `${apiBase.replace(/\/$/, '')}${event.path}`, { fetchOptions: { redirect: 'manual' } })
})
