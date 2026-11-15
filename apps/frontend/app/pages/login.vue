<script setup lang="ts">
import type { AuthFormField, ButtonProps, FormSubmitEvent } from '@nuxt/ui'
import { z } from 'zod'

definePageMeta({ layout: false })

useHead({ title: 'Entrar · maimoni' })

const route = useRoute()
const { signIn, signInWith, socialError } = useAuth()

const loading = ref(false)
// A failed Google or Apple sign in comes back here with `?error=<code>`.
const failure = ref<string | null>(socialError(route.query.error))

const SOCIAL_BUTTONS: { provider: SocialProvider, label: string, icon: string }[] = [
  { provider: 'google', label: 'Entrar com Google', icon: 'i-simple-icons-google' },
  { provider: 'apple', label: 'Entrar com Apple', icon: 'i-simple-icons-apple' },
]

// A provider is only offered when the backend has its credentials.
const { data: providers } = await useFetch<string[]>('/api/sign-in-providers', { key: 'sign-in-providers', default: () => [] })
/** The provider the browser is being sent to. */
const leavingFor = ref<SocialProvider | null>(null)
const providerButtons = computed<ButtonProps[]>(() => SOCIAL_BUTTONS
  .filter(button => providers.value.includes(button.provider))
  .map(({ provider, label, icon }) => ({
    label,
    icon,
    loading: leavingFor.value === provider,
    disabled: leavingFor.value !== null,
    onClick: () => social(provider),
  })))

async function social(provider: SocialProvider) {
  leavingFor.value = provider
  failure.value = null
  try {
    failure.value = await signInWith(provider, redirectTarget(route.query.redirect))
  }
  catch (error) {
    failure.value = errorMessage(error)
  }
  // On success the browser is leaving for the provider, so the button keeps spinning.
  if (failure.value)
    leavingFor.value = null
}

const fields: AuthFormField[] = [
  { name: 'email', type: 'email', label: 'E-mail', autocomplete: 'email', autofocus: true, required: true },
  { name: 'password', type: 'password', label: 'Senha', autocomplete: 'current-password', required: true },
]

const schema = z.object({
  email: z.email('Informe um e-mail válido'),
  password: z.string().min(1, 'Informe a senha'),
})
type Credentials = z.output<typeof schema>

async function submit(event: FormSubmitEvent<Credentials>) {
  loading.value = true
  failure.value = null
  try {
    failure.value = await signIn(event.data.email, event.data.password)
    if (!failure.value)
      await navigateTo(redirectTarget(route.query.redirect))
  }
  catch (error) {
    failure.value = errorMessage(error)
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-dvh items-center justify-center p-4">
    <UPageCard class="w-full max-w-sm">
      <UAuthForm
        :schema="schema"
        :fields="fields"
        title="maimoni"
        description="Entre com seu e-mail e senha."
        :providers="providerButtons"
        separator="ou"
        :submit="{ label: 'Entrar' }"
        :loading="loading"
        @submit="submit"
      >
        <template #password-hint>
          <ULink to="/forgot-password" class="font-medium text-primary" tabindex="-1">
            Esqueceu a senha?
          </ULink>
        </template>
        <template v-if="failure" #validation>
          <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :title="failure" />
        </template>
      </UAuthForm>
    </UPageCard>
  </main>
</template>
