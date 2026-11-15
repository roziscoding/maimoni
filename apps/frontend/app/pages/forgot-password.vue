<script setup lang="ts">
import type { PasswordResetRequest } from '@maimoni/shared'
import type { AuthFormField, FormSubmitEvent } from '@nuxt/ui'
import { z } from 'zod'

definePageMeta({ layout: false })

useHead({ title: 'Redefinir senha · maimoni' })

const fields: AuthFormField[] = [
  { name: 'email', type: 'email', label: 'E-mail', autocomplete: 'email', autofocus: true, required: true },
]

const schema = z.object({ email: z.email('Informe um e-mail válido') })

const loading = ref(false)
const failure = ref<string | null>(null)
/** The address the request was made for, once it went through. */
const sentTo = ref<string | null>(null)

async function submit(event: FormSubmitEvent<PasswordResetRequest>) {
  loading.value = true
  failure.value = null
  try {
    await $fetch('/api/password-reset', { method: 'POST', body: event.data })
    sentTo.value = event.data.email
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
      <div v-if="sentTo" class="space-y-4 text-center">
        <UIcon name="i-lucide-mail-check" class="size-8 text-primary" />
        <h1 class="text-xl font-semibold text-highlighted">
          Confira seu e-mail
        </h1>
        <p class="text-sm text-muted">
          Se existir uma conta para <span class="text-default">{{ sentTo }}</span>, enviamos um link para redefinir a senha. Ele vale por 1 hora.
        </p>
        <UButton to="/login" label="Voltar para o login" color="neutral" variant="subtle" block />
      </div>

      <UAuthForm
        v-else
        :schema="schema"
        :fields="fields"
        title="Redefinir senha"
        description="Informe seu e-mail para receber um link de redefinição."
        :submit="{ label: 'Enviar link' }"
        :loading="loading"
        @submit="submit"
      >
        <template v-if="failure" #validation>
          <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :title="failure" />
        </template>
        <template #footer>
          <ULink to="/login" class="font-medium text-primary">
            Voltar para o login
          </ULink>
        </template>
      </UAuthForm>
    </UPageCard>
  </main>
</template>
