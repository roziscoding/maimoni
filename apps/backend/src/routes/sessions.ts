import type { SessionEntry } from '@maimoni/shared'
import type { Auth, AuthEnv } from '../auth'
import { Hono } from 'hono'
import { z } from 'zod'
import { validate } from '../lib/validate'

const idParam = z.object({ id: z.uuid() })

/**
 * The user's sessions, so one left signed in elsewhere can be ended from here.
 *
 * Better Auth has its own `list-sessions` and `revoke-session`, which these replace: the first only
 * answers a session less than a day old, and both hand every session's token to the client.
 */
export function sessionRoutes(auth: Auth) {
  async function active(userId: string) {
    const { internalAdapter } = await auth.$context
    return { internalAdapter, sessions: await internalAdapter.listSessions(userId, { onlyActiveSessions: true }) }
  }

  return new Hono<AuthEnv>()
    .get('/sessions', async (c) => {
      const { sessions } = await active(c.var.user.id)
      const body: SessionEntry[] = sessions
        .map(session => ({
          id: session.id,
          current: session.id === c.var.session.id,
          userAgent: session.userAgent ?? null,
          ipAddress: session.ipAddress ?? null,
          createdAt: new Date(session.createdAt).toISOString(),
        }))
        // The current one first, then the most recent sign in.
        .sort((a, b) => Number(b.current) - Number(a.current) || b.createdAt.localeCompare(a.createdAt))
      return c.json(body)
    })
    // Ends every session but the one making the request.
    .delete('/sessions', async (c) => {
      const { internalAdapter, sessions } = await active(c.var.user.id)
      await internalAdapter.deleteSessions(sessions.filter(session => session.id !== c.var.session.id).map(session => session.token))
      return c.body(null, 204)
    })
    // Ends the session making the request, for clients that hold a bearer token rather than a cookie.
    // Better Auth's `sign-out` answers 200 even when deleting the session fails; here a failure
    // surfaces as a 500, so 204 means the token no longer works.
    .delete('/sessions/current', async (c) => {
      const { internalAdapter } = await auth.$context
      await internalAdapter.deleteSession(c.var.session.token)
      return c.body(null, 204)
    })
    .delete('/sessions/:id', validate('param', idParam), async (c) => {
      const { id } = c.req.valid('param')
      // On the web, signing out also clears the cookie, which this route doesn't.
      if (id === c.var.session.id)
        return c.json({ error: 'Sign out to end the current session' }, 400)
      const { internalAdapter, sessions } = await active(c.var.user.id)
      const session = sessions.find(session => session.id === id)
      if (!session)
        return c.json({ error: 'Session not found' }, 404)
      await internalAdapter.deleteSession(session.token)
      return c.body(null, 204)
    })
}
