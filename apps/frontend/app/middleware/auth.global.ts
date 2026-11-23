/** Pages that work without a session. */
const PUBLIC_PATHS = ['/login', '/forgot-password', '/reset-password']

/** The first-run setup, which a user sees until they finish or skip it. */
const ONBOARDING_PATH = '/onboarding'

/**
 * Sends signed out visitors to `/login` (keeping where they were going) and signed in ones away from it.
 * A signed in user who hasn't been through the first-run setup is held on it, and one who has is kept off it.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const { session, load } = useAuth()
  const current = session.value === undefined ? await load() : session.value

  if (to.path === '/login')
    return current ? navigateTo(redirectTarget(to.query.redirect)) : undefined
  if (!current)
    return PUBLIC_PATHS.includes(to.path) ? undefined : navigateTo({ path: '/login', query: to.fullPath === '/' ? undefined : { redirect: to.fullPath } })
  if (PUBLIC_PATHS.includes(to.path))
    return
  if (!current.user.onboarded && to.path !== ONBOARDING_PATH)
    return navigateTo(ONBOARDING_PATH)
  if (current.user.onboarded && to.path === ONBOARDING_PATH)
    return navigateTo('/')
})
