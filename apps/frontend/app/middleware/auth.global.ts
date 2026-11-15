/** Pages that work without a session. */
const PUBLIC_PATHS = ['/login', '/forgot-password', '/reset-password']

/** Sends signed out visitors to `/login` (keeping where they were going) and signed in ones away from it. */
export default defineNuxtRouteMiddleware(async (to) => {
  const { session, load } = useAuth()
  const current = session.value === undefined ? await load() : session.value

  if (to.path === '/login')
    return current ? navigateTo(redirectTarget(to.query.redirect)) : undefined
  if (!current && !PUBLIC_PATHS.includes(to.path))
    return navigateTo({ path: '/login', query: to.fullPath === '/' ? undefined : { redirect: to.fullPath } })
})
