<script setup lang="ts">
import type { Currency, EntryKind } from '@maimoni/shared'
import { evaluateExpression, isExpression } from '@maimoni/shared'
import * as z from 'zod'

export interface NewItem {
  name: string
  currency: Currency
  kind: EntryKind
  amount: number | null
  expression: string | null
}

const props = defineProps<{
  currency: Currency
}>()

const emit = defineEmits<{
  add: [item: NewItem]
}>()

const schema = z.object({
  name: z.string().trim().min(1, 'Dê um nome'),
  amount: z.string().trim().refine(value => !value || evaluateExpression(value) !== null, 'Número ou conta, ex.: 11,99+2,99'),
})

const state = reactive({ name: '', amount: '', kind: 'expense' as EntryKind })
const nameInput = useTemplateRef('nameInput')

function submit() {
  const amount = state.amount.trim()
  emit('add', {
    name: state.name.trim(),
    currency: props.currency,
    kind: state.kind,
    amount: amount ? evaluateExpression(amount) : null,
    expression: amount && isExpression(amount) ? amount.replace(/^=/, '') : null,
  })
  state.name = ''
  state.amount = ''
  nameInput.value?.inputRef?.focus()
}
</script>

<template>
  <UForm :schema="schema" :state="state" class="flex items-start gap-1 pt-1" @submit="submit">
    <UTooltip :text="state.kind === 'income' ? 'Entrada (clique para mudar para saída)' : 'Saída (clique para mudar para entrada)'">
      <UButton
        :icon="state.kind === 'income' ? 'i-lucide-arrow-down-left' : 'i-lucide-arrow-up-right'"
        :aria-label="state.kind === 'income' ? 'Tipo: entrada' : 'Tipo: saída'"
        color="neutral"
        variant="ghost"
        class="mt-px"
        @click="state.kind = state.kind === 'income' ? 'expense' : 'income'"
      />
    </UTooltip>
    <UFormField name="name" class="min-w-0 flex-1">
      <UInput ref="nameInput" v-model="state.name" :placeholder="state.kind === 'income' ? 'Nova entrada' : 'Nova saída'" class="w-full" />
    </UFormField>
    <UFormField name="amount" class="w-32 sm:w-40">
      <UInput v-model="state.amount" placeholder="0,00" inputmode="decimal" class="w-full" :ui="{ base: 'money text-right' }" />
    </UFormField>
    <UButton type="submit" icon="i-lucide-plus" color="neutral" variant="subtle" aria-label="Adicionar" />
  </UForm>
</template>
