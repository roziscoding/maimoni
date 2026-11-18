<script setup lang="ts">
import type { Settings, TemplateDetail } from '@maimoni/shared'
import type { FormSubmitEvent } from '@nuxt/ui'
import { settingsSchema } from '@maimoni/shared'

useHead({ title: 'Configurações · maimoni' })

const toast = useToast()
const { data, error, refresh } = await useFetch<TemplateDetail>('/api/template', { key: 'template' })

const state = reactive<Partial<Settings>>({ wiseFee: data.value?.settings.wiseFee })
watch(() => data.value?.settings.wiseFee, (value) => {
  state.wiseFee = value
})

const saving = ref(false)
async function submit(event: FormSubmitEvent<Settings>) {
  saving.value = true
  try {
    const settings = await $fetch<Settings>('/api/settings', { method: 'PATCH', body: event.data })
    if (data.value)
      data.value = { ...data.value, settings }
    toast.add({ title: 'Configurações salvas', color: 'success', icon: 'i-lucide-check' })
  }
  catch (err) {
    toast.add({ title: 'Não foi possível salvar', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    saving.value = false
  }
}

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
    toast.add({ title: 'Dados apagados', description: 'Meses, template e configurações voltaram ao zero.', color: 'neutral', icon: 'i-lucide-trash-2' })
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
        <UForm v-if="data" :schema="settingsSchema" :state="state" class="space-y-6" @submit="submit">
          <UFormField
            name="wiseFee"
            label="Taxa Wise de reserva"
            description="Os meses usam a taxa real cotada pela Wise para o valor enviado. Esta só entra quando a Wise não responde."
          >
            <UInputNumber
              v-model="state.wiseFee"
              :min="0"
              :max="0.99"
              :step="0.001"
              locale="pt-BR"
              :format-options="{ style: 'percent', minimumFractionDigits: 1, maximumFractionDigits: 2 }"
              class="w-40"
              :ui="{ base: 'money' }"
            />
          </UFormField>
          <UButton type="submit" label="Salvar" :loading="saving" />
        </UForm>

        <UEmpty
          v-else-if="error"
          icon="i-lucide-cloud-off"
          title="Não foi possível carregar as configurações"
          :description="errorMessage(error)"
          variant="naked"
          :actions="[{ label: 'Tentar de novo', icon: 'i-lucide-refresh-cw', color: 'neutral', variant: 'subtle', onClick: () => refresh() }]"
        />

        <SessionList class="mt-12" />

        <section aria-labelledby="danger-title" class="mt-12 space-y-3 rounded-xl border border-error/40 p-4">
          <div class="space-y-1">
            <h2 id="danger-title" class="text-sm font-semibold text-error">
              Zona de perigo
            </h2>
            <p class="text-sm text-muted">
              Apaga todos os meses, o template, as configurações e o histórico de cotações. Não dá para desfazer.
            </p>
          </div>
          <UButton label="Apagar todos os dados" icon="i-lucide-trash-2" color="error" variant="subtle" @click="confirmingClear = true" />
        </section>

        <UModal
          v-model:open="confirmingClear"
          title="Apagar todos os dados?"
          description="Meses, itens, template, configurações e cotações salvas serão apagados de vez."
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
