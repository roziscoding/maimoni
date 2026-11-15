const SIGN_IN_ERRORS: Record<string, string> = {
  INVALID_EMAIL_OR_PASSWORD: 'E-mail ou senha incorretos.',
  INVALID_EMAIL: 'E-mail inválido.',
}

/** Sign in providers the page has a button for, besides email and password. */
export type SocialProvider = 'google' | 'apple'

const SOCIAL_ERRORS: Record<string, string> & { default: string } = {
  default: 'Não foi possível entrar com essa conta.',
  signup_disabled: 'Não existe uma conta do maimoni para o e-mail dessa conta.',
}

const RESET_ERRORS: Record<string, string> = {
  INVALID_TOKEN: 'O link é inválido ou expirou. Peça um novo.',
  PASSWORD_TOO_SHORT: 'A senha é curta demais.',
  PASSWORD_TOO_LONG: 'A senha é longa demais.',
}

/**
 * The signed in user, shared across the app. `session` is `undefined` until the first check,
 * then `null` when signed out.
 */
export function useAuth() {
  const session = useState<AuthSession | null | undefined>('auth-session', () => undefined)
  const user = computed(() => session.value?.user ?? null)

  /** Asks the backend who is signed in. A failed request leaves the state alone, so the next call tries again. */
  async function load() {
    const { data, error } = await authClient.getSession()
    if (!error)
      session.value = data ?? null
    return session.value ?? null
  }

  /** Returns an error message in Portuguese, or `null` once signed in. */
  async function signIn(email: string, password: string) {
    const { error } = await authClient.signIn.email({ email, password })
    if (error) {
      if (error.status === 429)
        return 'Muitas tentativas. Espere um pouco e tente de novo.'
      return SIGN_IN_ERRORS[error.code ?? ''] ?? error.message ?? 'Não foi possível entrar.'
    }
    if (!await load())
      return 'Não foi possível entrar.'
    return null
  }

  /**
   * Sends the browser to the provider, which comes back to `callbackURL` signed in, or to `/login?error=<code>`.
   * Returns an error message in Portuguese when the redirect couldn't start.
   */
  async function signInWith(provider: SocialProvider, callbackURL: string) {
    const { error } = await authClient.signIn.social({ provider, callbackURL, errorCallbackURL: '/login' })
    return error ? SOCIAL_ERRORS.default : null
  }

  /** Message for the `error` code a failed social sign in leaves in the URL. */
  function socialError(code: unknown) {
    return typeof code === 'string' && code ? SOCIAL_ERRORS[code] ?? SOCIAL_ERRORS.default : null
  }

  /** Sets a new password with the token from the emailed link. Returns an error message in Portuguese, or `null` once changed. */
  async function resetPassword(token: string, newPassword: string) {
    const { error } = await authClient.resetPassword({ token, newPassword })
    if (!error)
      return null
    return RESET_ERRORS[error.code ?? ''] ?? error.message ?? 'Não foi possível alterar a senha.'
  }

  /** Ends the session and drops every cached response, so the next user starts clean. */
  async function signOut() {
    const { error } = await authClient.signOut()
    if (error)
      throw new Error(error.message ?? 'Não foi possível sair.')
    session.value = null
    clearNuxtData()
    await navigateTo('/login')
  }

  return { session, user, load, signIn, signInWith, socialError, resetPassword, signOut }
}
