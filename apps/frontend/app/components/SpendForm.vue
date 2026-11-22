<script setup lang="ts">
import type { CreateDailySpend, Currency, DailySpend } from '@maimoni/shared'
import { dailySpendInput } from '@maimoni/shared'

const props = withDefaults(defineProps<{
  day: number
  create: (input: CreateDailySpend) => Promise<DailySpend | undefined>
  autofocus?: boolean
}>(), { autofocus: false })

const toast = useToast()
const amount = ref('')
const note = ref('')
const { offered, main } = useCurrencies()
// Kept between entries: a run of spends usually happens in the same currency.
const picked = ref<Currency | null>(null)
/** The currency the spend goes in: the picked one while it is still offered, otherwise the main one. */
const currency = computed(() => picked.value && offered.value.includes(picked.value) ? picked.value : main.value)
const amountInput = useTemplateRef('amountInput')
const saving = ref(false)

/** Moves to the next offered currency. There is nothing to pick from with a single one. */
function nextCurrency() {
  if (currency.value)
    picked.value = offered.value[(offered.value.indexOf(currency.value) + 1) % offered.value.length] ?? null
}

async function submit() {
  if (!currency.value)
    return
  const input = dailySpendInput({ day: props.day, currency: currency.value, amountText: amount.value, note: note.value })
  if (!input) {
    const text = amount.value.trim()
    toast.add({ title: 'Valor inválido', description: `"${text}" não é um número nem uma conta como 4,50+2.`, color: 'error', icon: 'i-lucide-circle-alert' })
    return
  }
  saving.value = true
  const created = await props.create(input)
  saving.value = false
  if (created) {
    amount.value = ''
    note.value = ''
    amountInput.value?.inputRef?.focus()
  }
}
</script>

<template>
  <!-- On phones the description drops to its own row so neither field gets cramped. -->
  <form v-if="currency" class="flex flex-wrap items-start gap-2 sm:flex-nowrap" :aria-label="`Lançar gasto no dia ${day}`" @submit.prevent="submit">
    <UButton
      v-if="offered.length > 1"
      :label="currencySymbol(currency)"
      :aria-label="`Gasto em ${currencyPlural(currency).toLowerCase()} (trocar a moeda)`"
      color="neutral"
      variant="subtle"
      size="xl"
      class="money w-12 shrink-0 justify-center"
      @click="nextCurrency"
    />
    <UInput
      ref="amountInput"
      v-model="amount"
      placeholder="0,00"
      inputmode="decimal"
      autocomplete="off"
      :aria-label="`Valor em ${currencyPlural(currency).toLowerCase()}`"
      size="xl"
      class="min-w-0 flex-1 sm:w-40 sm:flex-none"
      :ui="{ base: 'money' }"
      :autofocus="autofocus"
    />
    <UInput
      v-model="note"
      placeholder="Com o quê?"
      aria-label="Descrição"
      size="xl"
      class="order-last basis-full sm:order-none sm:min-w-0 sm:flex-1 sm:basis-auto"
    />
    <UButton type="submit" label="Lançar" size="xl" :loading="saving" :disabled="!amount.trim()" />
  </form>
</template>
