<script setup lang="ts">
import type { CreateMonth, Currency, MonthDetail } from '@maimoni/shared'

const props = defineProps<{
  year: number
  month: number
  /** Whether an earlier month exists to copy from. */
  hasPrevious: boolean
}>()

const toast = useToast()
const pending = ref<CreateMonth['source'] | null>(null)
const mainCurrency = ref<Currency>()

async function create(source: NonNullable<CreateMonth['source']>) {
  pending.value = source
  try {
    await $fetch<MonthDetail>('/api/months', { method: 'POST', body: { year: props.year, month: props.month, source, mainCurrency: mainCurrency.value } satisfies CreateMonth })
    await refreshNuxtData('months')
    await navigateTo(`/months/${props.year}/${props.month}`)
  }
  catch (error) {
    toast.add({ title: 'Não foi possível criar o mês', description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    pending.value = null
  }
}
</script>

<template>
  <UEmpty
    icon="i-lucide-calendar-plus"
    :title="`${monthLabel(year, month)} ainda não existe`"
    description="Comece pelo template, com os valores fixos de sempre, ou copie o último mês como está."
    variant="naked"
    :ui="{ body: 'w-full gap-6' }"
  >
    <!-- The body slot takes the place of the actions, so the buttons go in it, under the currency. -->
    <template #body>
      <MonthCurrencyChoice v-model="mainCurrency" :disabled="pending !== null" />
      <div class="flex flex-wrap justify-center gap-2">
        <UButton
          label="Criar do template"
          icon="i-lucide-layout-template"
          :loading="pending === 'template'"
          :disabled="pending !== null"
          @click="create('template')"
        />
        <UButton
          label="Copiar mês anterior"
          icon="i-lucide-copy"
          color="neutral"
          variant="subtle"
          :loading="pending === 'previous'"
          :disabled="pending !== null || !hasPrevious"
          @click="create('previous')"
        />
      </div>
    </template>
  </UEmpty>
</template>
