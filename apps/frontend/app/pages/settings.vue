<script setup lang="ts">
import type { Flags } from '@maimoni/shared'

useHead({ title: 'Configurações · maimoni' })

const toast = useToast()
// The danger zone only shows when the server serves `DELETE /api/data`.
const { data: flags } = await useFetch<Flags>('/api/flags', { key: 'flags' })

const CONFIRMATION = 'apagar'
const clearing = ref(false)
const confirmingClear = ref(false)
const confirmation = ref('')
watch(confirmingClear, () => {
  confirmation.value = ''
})

async function clearData() {
  clearing.value = true
  try {
    await $fetch('/api/data', { method: 'DELETE' })
    confirmingClear.value = false
    clearNuxtData()
    await refreshNuxtData()
    toast.add({ title: 'Dados apagados', description: 'Todos os meses e o template foram apagados.', color: 'neutral', icon: 'i-lucide-trash-2' })
    await navigateTo('/')
  }
  catch (err) {
    toast.add({ title: 'Não foi possível apagar os dados', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    clearing.value = false
  }
}
</script>

<template>
  <UDashboardPanel id="settings">
    <template #header>
      <UDashboardNavbar title="Configurações" />
    </template>

    <template #body>
      <div class="mx-auto w-full max-w-2xl space-y-6 py-4">
        <CurrencySettings />

        <SessionList />

        <SettingsSection v-if="flags?.purge" title="Zona de perigo" description="Ações que não podem ser desfeitas." danger>
          <div class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3">
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium text-highlighted">
                Apagar todos os dados
              </p>
              <p class="text-sm text-muted">
                Apaga todos os meses e o template. Moedas e sessões são mantidas.
              </p>
            </div>
            <UButton label="Apagar todos os dados" icon="i-lucide-trash-2" color="error" variant="subtle" size="sm" @click="confirmingClear = true" />
          </div>
        </SettingsSection>

        <UModal
          v-model:open="confirmingClear"
          title="Apagar todos os dados?"
          description="Todos os meses e o template serão apagados. Esta ação não pode ser desfeita."
          :ui="{ footer: 'justify-end' }"
        >
          <template #body>
            <UFormField :label="`Digite &quot;${CONFIRMATION}&quot; para confirmar`" name="confirmation">
              <UInput v-model="confirmation" autocomplete="off" class="w-full" @keydown.enter="confirmation === CONFIRMATION && clearData()" />
            </UFormField>
          </template>
          <template #footer="{ close }">
            <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
            <UButton label="Apagar todos os dados" color="error" icon="i-lucide-trash-2" :disabled="confirmation !== CONFIRMATION" :loading="clearing" @click="clearData" />
          </template>
        </UModal>
      </div>
    </template>
  </UDashboardPanel>
</template>
