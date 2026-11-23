<script setup lang="ts">
import type { Currency, EntryKind, TemplateItem } from '@maimoni/shared'
import type { NewItem } from '~/components/AddItemForm.vue'
import { evaluateExpression, isExpression } from '@maimoni/shared'
import * as z from 'zod'

const props = defineProps<{
  /** Every item added here is of this kind. */
  kind: EntryKind
  /** The template's items of that kind. */
  items: TemplateItem[]
  /** The currencies an item can be in. With a single one there is nothing to choose. */
  currencies: Currency[]
  /** The currency a new item starts in. */
  main: Currency | null
  /** An example of a name, shown while the field is empty. */
  example: string
}>()

const emit = defineEmits<{
  add: [item: NewItem]
  remove: [id: string]
}>()

const schema = z.object({
  name: z.string().trim().min(1, 'Dê um nome'),
  amount: z.string().trim().min(1, 'Informe o valor').refine(value => !value || evaluateExpression(value) !== null, 'Use um número, como 1.250,00'),
})

const state = reactive({ name: '', amount: '', currency: props.main ?? props.currencies[0] })
const form = useTemplateRef('form')
const nameInput = useTemplateRef('nameInput')

function submit() {
  if (!state.currency)
    return
  const amount = state.amount.trim()
  emit('add', {
    name: state.name.trim(),
    currency: state.currency,
    kind: props.kind,
    amount: evaluateExpression(amount),
    expression: isExpression(amount) ? amount.replace(/^=/, '') : null,
  })
  state.name = ''
  state.amount = ''
  nameInput.value?.inputRef?.focus()
}

/**
 * Adds what is typed in the form but wasn't added yet, so moving on doesn't throw it away.
 * Returns `false` when it can't be added as it is; the form then says what is missing.
 */
/** Whether something is typed in the form and not on the list yet. */
const hasDraft = computed(() => Boolean(state.name.trim() || state.amount.trim()))

async function commitPending() {
  if (!hasDraft.value)
    return true
  if (!schema.safeParse(state).success) {
    await form.value?.validate({ silent: true })
    return false
  }
  submit()
  return true
}

defineExpose({ commitPending, hasDraft })
</script>

<template>
  <div class="space-y-3">
    <ul v-if="items.length" class="divide-y divide-default rounded-lg border border-default">
      <li v-for="item in items" :key="item.id" class="flex items-center gap-3 py-1.5 pl-3 pr-1.5">
        <span class="min-w-0 flex-1 truncate text-sm text-highlighted">{{ item.name }}</span>
        <span class="money text-sm text-toned">{{ formatMoney(item.amount, item.currency) }}</span>
        <UButton
          icon="i-lucide-x"
          color="neutral"
          variant="ghost"
          size="xs"
          :aria-label="`Remover ${item.name}`"
          @click="emit('remove', item.id)"
        />
      </li>
    </ul>

    <UForm ref="form" :schema="schema" :state="state" class="space-y-2" @submit="submit">
      <div class="flex items-start gap-2">
        <UFormField name="name" class="min-w-0 flex-1">
          <UInput ref="nameInput" v-model="state.name" :placeholder="example" aria-label="Nome" autofocus class="w-full" />
        </UFormField>
        <UFormField name="amount" class="w-28">
          <UInput v-model="state.amount" placeholder="0,00" inputmode="decimal" aria-label="Valor" class="w-full" :ui="{ base: 'money text-right' }" />
        </UFormField>
        <USelect v-if="currencies.length > 1" v-model="state.currency" :items="currencies" aria-label="Moeda" class="w-22" :ui="{ base: 'money' }" />
      </div>
      <!-- Puts what is filled in on the list and empties the form for the next one. Moving on adds it too. -->
      <UButton type="submit" label="Adicionar outro" icon="i-lucide-plus" color="neutral" variant="subtle" block />
    </UForm>
  </div>
</template>
