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
// Kept between entries: a run of spends usually happens in the same currency.
const currency = ref<Currency>('EUR')
const amountInput = useTemplateRef('amountInput')
const saving = ref(false)

async function submit() {
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
  <form class="flex flex-wrap items-start gap-2 sm:flex-nowrap" :aria-label="`Lançar gasto no dia ${day}`" @submit.prevent="submit">
    <UButton
      :label="currency === 'EUR' ? '€' : 'R$'"
      :aria-label="currency === 'EUR' ? 'Gasto em euros (trocar para reais)' : 'Gasto em reais (trocar para euros)'"
      color="neutral"
      variant="subtle"
      size="xl"
      class="money w-12 shrink-0 justify-center"
      @click="currency = currency === 'EUR' ? 'BRL' : 'EUR'"
    />
    <UInput
      ref="amountInput"
      v-model="amount"
      placeholder="0,00"
      inputmode="decimal"
      autocomplete="off"
      :aria-label="currency === 'EUR' ? 'Valor em euros' : 'Valor em reais'"
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
