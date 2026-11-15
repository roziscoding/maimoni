<script setup lang="ts">
import type { AuthFormField, FormSubmitEvent } from '@nuxt/ui'
import { z } from 'zod'

definePageMeta({ layout: false })

useHead({ title: 'Nova senha · maimoni' })

const route = useRoute()
const toast = useToast()
const { resetPassword } = useAuth()

/** The emailed link lands here with `?token=`, or with `?error=` when the token is invalid or expired. */
const token = computed(() => typeof route.query.token === 'string' && !route.query.error ? route.query.token : null)

const fields: AuthFormField[] = [
  { name: 'password', type: 'password', label: 'Nova senha', autocomplete: 'new-password', autofocus: true, required: true },
]

// Better Auth's default limits.
const schema = z.object({
  password: z.string().min(8, 'Use pelo menos 8 caracteres').max(128, 'Use no máximo 128 caracteres'),
})
type NewPassword = z.output<typeof schema>

const loading = ref(false)
const failure = ref<string | null>(null)

async function submit(event: FormSubmitEvent<NewPassword>) {
  if (!token.value)
    return
  loading.value = true
  failure.value = null
  try {
    failure.value = await resetPassword(token.value, event.data.password)
    if (!failure.value) {
      toast.add({ title: 'Senha alterada', description: 'Entre com a nova senha.', color: 'success', icon: 'i-lucide-check' })
      await navigateTo('/login')
    }
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
        v-if="token"
        :schema="schema"
        :fields="fields"
        title="Nova senha"
        description="Escolha a senha que você vai usar para entrar."
        :submit="{ label: 'Salvar senha' }"
        :loading="loading"
        @submit="submit"
      >
        <template v-if="failure" #validation>
          <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :title="failure" />
        </template>
      </UAuthForm>

      <div v-else class="space-y-4 text-center">
        <UIcon name="i-lucide-link-2-off" class="size-8 text-error" />
        <h1 class="text-xl font-semibold text-highlighted">
          Link inválido ou expirado
        </h1>
        <p class="text-sm text-muted">
          Peça um novo link para redefinir a senha.
        </p>
        <UButton to="/forgot-password" label="Pedir novo link" block />
      </div>
    </UPageCard>
  </main>
</template>
