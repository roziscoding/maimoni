<script setup lang="ts">
import type { MonthDetail, MonthListEntry } from '@maimoni/shared'
import type { FormSubmitEvent } from '@nuxt/ui'
import type * as z from 'zod'
import { createMonthSchema } from '@maimoni/shared'

type NewMonth = z.output<typeof createMonthSchema>

const props = defineProps<{
  months: MonthListEntry[]
}>()

const open = defineModel<boolean>('open', { required: true })

const toast = useToast()
const saving = ref(false)
const state = reactive<NewMonth>({ year: 0, month: 1, source: 'template' })

const monthOptions = Array.from({ length: 12 }, (_, index) => ({ label: monthName(index + 1), value: index + 1 }))
const sourceOptions = [
  { label: 'Template', value: 'template', description: 'Valores fixos de sempre; os variáveis chegam para confirmar.' },
  { label: 'Mês anterior', value: 'previous', description: 'Copia os itens do último mês antes deste, como estão.' },
]

const taken = computed(() => props.months.some(entry => entry.year === state.year && entry.month === state.month))

// Every time the modal opens, suggest the first month from now on that doesn't exist yet.
watch(open, (value) => {
  if (!value)
    return
  const now = new Date()
  let index = now.getFullYear() * 12 + now.getMonth()
  while (props.months.some(entry => entry.year * 12 + entry.month - 1 === index))
    index++
  Object.assign(state, { year: Math.floor(index / 12), month: (index % 12) + 1, source: 'template', mainCurrency: undefined })
}, { immediate: true })

async function submit(event: FormSubmitEvent<NewMonth>) {
  saving.value = true
  try {
    const { year, month } = event.data
    await $fetch<MonthDetail>('/api/months', { method: 'POST', body: event.data })
    await refreshNuxtData('months')
    open.value = false
    await navigateTo(`/months/${year}/${month}`)
  }
  catch (error) {
    toast.add({ title: 'Não foi possível criar o mês', description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <UModal v-model:open="open" title="Novo mês" description="Escolha o mês e de onde vêm os itens." :ui="{ footer: 'justify-end' }">
    <template #body>
      <UForm id="new-month" :schema="createMonthSchema" :state="state" class="space-y-5" @submit="submit">
        <div class="grid grid-cols-[minmax(0,1fr)_7rem] gap-3">
          <UFormField name="month" label="Mês">
            <USelect v-model="state.month" :items="monthOptions" class="w-full" />
          </UFormField>
          <UFormField name="year" label="Ano">
            <UInputNumber v-model="state.year" :min="2000" :max="2100" :format-options="{ useGrouping: false }" class="w-full" />
          </UFormField>
        </div>

        <UAlert
          v-if="taken"
          color="warning"
          variant="subtle"
          icon="i-lucide-calendar-x"
          :title="`${monthLabel(state.year, state.month)} já existe`"
          :actions="[{ label: 'Abrir', color: 'neutral', variant: 'outline', to: `/months/${state.year}/${state.month}`, onClick: () => (open = false) }]"
        />

        <UFormField name="source" label="Itens">
          <URadioGroup v-model="state.source" :items="sourceOptions" variant="table" />
        </UFormField>

        <MonthCurrencyChoice v-model="state.mainCurrency" name="mainCurrency" />
      </UForm>
    </template>

    <template #footer="{ close }">
      <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
      <UButton type="submit" form="new-month" label="Criar mês" icon="i-lucide-calendar-plus" :loading="saving" :disabled="taken" />
    </template>
  </UModal>
</template>
