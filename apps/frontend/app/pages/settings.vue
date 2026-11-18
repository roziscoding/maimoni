<script setup lang="ts">
useHead({ title: 'Configurações · maimoni' })

const toast = useToast()

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
    toast.add({ title: 'Dados apagados', description: 'Meses e template voltaram ao zero.', color: 'neutral', icon: 'i-lucide-trash-2' })
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
      <div class="mx-auto w-full max-w-xl py-4">
        <SessionList />

        <section aria-labelledby="danger-title" class="mt-12 space-y-3 rounded-xl border border-error/40 p-4">
          <div class="space-y-1">
            <h2 id="danger-title" class="text-sm font-semibold text-error">
              Zona de perigo
            </h2>
            <p class="text-sm text-muted">
              Apaga todos os meses e o template. Não dá para desfazer.
            </p>
          </div>
          <UButton label="Apagar todos os dados" icon="i-lucide-trash-2" color="error" variant="subtle" @click="confirmingClear = true" />
        </section>

        <UModal
          v-model:open="confirmingClear"
          title="Apagar todos os dados?"
          description="Meses, itens e template serão apagados de vez."
          :ui="{ footer: 'justify-end' }"
        >
          <template #body>
            <UFormField :label="`Digite &quot;${CONFIRMATION}&quot; para confirmar`" name="confirmation">
              <UInput v-model="confirmation" autocomplete="off" class="w-full" @keydown.enter="confirmation === CONFIRMATION && clearData()" />
            </UFormField>
          </template>
          <template #footer="{ close }">
            <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
            <UButton label="Apagar tudo" color="error" icon="i-lucide-trash-2" :disabled="confirmation !== CONFIRMATION" :loading="clearing" @click="clearData" />
          </template>
        </UModal>
      </div>
    </template>
  </UDashboardPanel>
</template>
