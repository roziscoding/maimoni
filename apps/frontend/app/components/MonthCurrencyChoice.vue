<script setup lang="ts">
import type { Currency } from '@maimoni/shared'

/**
 * Which currency a new month is worked out in, among the offered ones, by name. Renders nothing
 * with a single currency: there is nothing to choose.
 */
const props = defineProps<{
  /** Field name, for a form that validates it. */
  name?: string
  disabled?: boolean
}>()

const currency = defineModel<Currency | undefined>({ required: true })

const { offered, main } = useCurrencies()

// The main one first, as it is the usual pick; the rest in the app's order.
const items = computed(() => offered.value
  .toSorted((a, b) => Number(b === main.value) - Number(a === main.value))
  .map(value => ({ value, label: currencyName(value), description: currencySymbol(value) })))

// Follows the main one until the list loads, and whenever the picked one stops being offered.
watch([offered, main], () => {
  if (!currency.value || !offered.value.includes(currency.value))
    currency.value = main.value ?? undefined
}, { immediate: true })
</script>

<template>
  <UFormField
    v-if="offered.length > 1"
    :name="props.name"
    label="Moeda do mês"
    description="Os totais e o saldo saem nela. As outras moedas entram convertidas pela cotação."
    class="w-full text-start"
  >
    <URadioGroup
      v-model="currency"
      :items="items"
      :disabled="props.disabled"
      variant="table"
      class="mt-1"
    >
      <template #label="{ item }">
        <span class="flex items-center gap-2">
          {{ item.label }}
          <UBadge v-if="item.value === main" label="Principal" size="sm" color="neutral" variant="subtle" />
        </span>
      </template>
    </URadioGroup>
  </UFormField>
</template>
