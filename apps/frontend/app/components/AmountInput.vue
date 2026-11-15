<script setup lang="ts">
import type { Currency } from '@maimoni/shared'
import { evaluateExpression, isExpression } from '@maimoni/shared'

export interface AmountValue {
  amount: number | null
  expression: string | null
}

const props = withDefaults(defineProps<AmountValue & {
  currency: Currency
  placeholder?: string
  label: string
  highlight?: boolean
}>(), { placeholder: 'preencher', highlight: false })

const emit = defineEmits<{
  commit: [value: AmountValue]
}>()

const toast = useToast()
const focused = ref(false)
const draft = ref('')

/** What the person typed last time: the expression, or the plain number with a pt-BR comma. */
const raw = computed(() => props.expression ?? (props.amount === null ? '' : String(props.amount).replace('.', ',')))
const display = computed(() => props.amount === null ? '' : formatMoney(props.amount, props.currency))

function onFocus(event: FocusEvent) {
  draft.value = raw.value
  focused.value = true
  // Select once the raw value replaced the formatted one, so typing overwrites it.
  const input = event.target as HTMLInputElement
  nextTick(() => input.select())
}

function commit() {
  if (!focused.value)
    return
  focused.value = false
  const text = draft.value.trim()
  if (text === raw.value)
    return
  if (!text) {
    emit('commit', { amount: null, expression: null })
    return
  }
  const amount = evaluateExpression(text)
  if (amount === null) {
    toast.add({ title: 'Valor inválido', description: `"${text}" não é um número nem uma conta como 11,99+2,99.`, color: 'error', icon: 'i-lucide-circle-alert' })
    return
  }
  emit('commit', { amount, expression: isExpression(text) ? text.replace(/^=/, '') : null })
}

function cancel(event: KeyboardEvent) {
  draft.value = raw.value
  ;(event.target as HTMLInputElement).blur()
}
</script>

<template>
  <UInput
    :model-value="focused ? draft : display"
    :placeholder="placeholder"
    :aria-label="label"
    :highlight="highlight"
    color="warning"
    variant="ghost"
    inputmode="decimal"
    autocomplete="off"
    :ui="{ base: 'money text-right tabular-nums', trailing: 'pe-2' }"
    @update:model-value="draft = String($event)"
    @focus="onFocus"
    @blur="commit"
    @keydown.enter="($event.target as HTMLInputElement).blur()"
    @keydown.esc="cancel"
  >
    <template v-if="expression && !focused" #trailing>
      <UTooltip :text="`= ${expression}`">
        <UIcon name="i-lucide-sigma" class="size-3.5 text-dimmed" aria-label="Valor calculado por uma conta" />
      </UTooltip>
    </template>
  </UInput>
</template>
