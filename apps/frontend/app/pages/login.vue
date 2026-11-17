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

const SOCIAL_PROVIDERS: SocialProvider[] = ['google', 'apple']

// A provider is only offered when the backend has its credentials.
const { data: providers } = await useFetch<string[]>('/api/sign-in-providers', { key: 'sign-in-providers', default: () => [] })
const offered = computed(() => SOCIAL_PROVIDERS.filter(provider => providers.value.includes(provider)))
/** The provider the browser is being sent to. */
const leavingFor = ref<SocialProvider | null>(null)
// The form draws its separator only when it is given providers. The buttons themselves come from
// the `providers` slot, since Google and Apple each prescribe how theirs looks.
const providerButtons = computed<ButtonProps[]>(() => offered.value.map(provider => ({ label: provider })))

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
        <template v-if="offered.length" #providers>
          <!--
            Google's branding guidelines: the light theme's fill, stroke and text colors, Google
            Sans Medium 14/20, the standard color "G", 12px before the logo, 10px after it and 12px
            after the text. The light theme is used in dark mode too, where it matches the form's
            own white button; Google's themes aren't tied to the page's.
          -->
          <button
            v-if="offered.includes('google')"
            type="button"
            class="flex h-10 w-full items-center justify-center gap-2.5 rounded-md border border-[#747775] bg-white px-3 font-google text-sm/5 font-medium text-[#1f1f1f] disabled:cursor-not-allowed disabled:opacity-75"
            :disabled="leavingFor !== null"
            @click="social('google')"
          >
            <UIcon v-if="leavingFor === 'google'" name="i-lucide-loader-circle" class="size-5 animate-spin" />
            <img v-else src="/sign-in/google-g.png" alt="" class="size-5">
            Continuar com o Google
          </button>
          <!--
            Apple's guidelines for a custom button: black on a light background and white on a dark
            one, Apple's logo artwork at the button's full height (40px, no vertical padding), a
            title at 43% of that height, and at least 8% of the width after the title. The title is
            Apple's own wording for pt-BR.
          -->
          <button
            v-if="offered.includes('apple')"
            type="button"
            class="flex h-10 w-full items-center justify-center rounded-md bg-black px-[8%] text-[17px] font-medium text-white disabled:cursor-not-allowed disabled:opacity-75 dark:bg-white dark:text-black"
            :disabled="leavingFor !== null"
            @click="social('apple')"
          >
            <span v-if="leavingFor === 'apple'" class="flex h-10 w-7 items-center justify-center">
              <UIcon name="i-lucide-loader-circle" class="size-5 animate-spin" />
            </span>
            <template v-else>
              <img src="/sign-in/apple-logo-white.svg" alt="" class="h-10 w-auto dark:hidden">
              <img src="/sign-in/apple-logo-black.svg" alt="" class="hidden h-10 w-auto dark:block">
            </template>
            Continuar com a Apple
          </button>
        </template>
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
