<script setup lang="ts">
import type { TemplateItem, UpdateTemplateItem } from '@maimoni/shared'
import type { DropdownMenuItem } from '@nuxt/ui'

const props = defineProps<{
  item: TemplateItem
  first: boolean
  last: boolean
}>()

const emit = defineEmits<{
  update: [patch: UpdateTemplateItem]
  move: [offset: -1 | 1]
  remove: []
}>()

function renameTo(value: string) {
  const name = value.trim()
  if (name && name !== props.item.name)
    emit('update', { name })
}

const menu = computed<DropdownMenuItem[][]>(() => [
  [{
    label: props.item.kind === 'income' ? 'Mover para saídas' : 'Mover para entradas',
    icon: props.item.kind === 'income' ? 'i-lucide-arrow-up-right' : 'i-lucide-arrow-down-left',
    onSelect: () => emit('update', { kind: props.item.kind === 'income' ? 'expense' : 'income' }),
  }],
  [{ label: 'Excluir', icon: 'i-lucide-trash-2', color: 'error', onSelect: () => emit('remove') }],
])
</script>

<template>
  <li class="group grid grid-cols-[auto_minmax(0,1fr)_minmax(7.5rem,10rem)_auto_auto] items-center gap-x-1 rounded-md px-1 py-0.5 hover:bg-elevated/60 focus-within:bg-elevated/60">
    <div class="flex flex-col">
      <UButton
        icon="i-lucide-chevron-up"
        size="xs"
        color="neutral"
        variant="ghost"
        :disabled="first"
        :aria-label="`Subir ${item.name}`"
        class="py-0"
        @click="emit('move', -1)"
      />
      <UButton
        icon="i-lucide-chevron-down"
        size="xs"
        color="neutral"
        variant="ghost"
        :disabled="last"
        :aria-label="`Descer ${item.name}`"
        class="py-0"
        @click="emit('move', 1)"
      />
    </div>

    <UInput
      :model-value="item.name"
      :aria-label="`Nome de ${item.name}`"
      variant="ghost"
      class="min-w-0"
      @change="renameTo(($event.target as HTMLInputElement).value)"
      @keydown.enter="($event.target as HTMLInputElement).blur()"
    />

    <AmountInput
      :amount="item.amount"
      :expression="item.expression"
      :currency="item.currency"
      :label="`Valor de ${item.name}`"
      :placeholder="item.variable ? 'varia' : 'sem valor'"
      @commit="emit('update', $event)"
    />

    <UTooltip :text="item.variable ? 'Muda todo mês: o mês novo pede confirmação' : 'Fixo: entra no mês novo como está'">
      <USwitch
        :model-value="item.variable"
        size="sm"
        label="varia"
        :aria-label="`${item.name} muda todo mês`"
        class="px-2"
        :ui="{ label: 'text-xs text-muted font-normal' }"
        @update:model-value="emit('update', { variable: $event })"
      />
    </UTooltip>

    <UDropdownMenu :items="menu" :content="{ align: 'end' }">
      <UButton icon="i-lucide-ellipsis" color="neutral" variant="ghost" size="sm" :aria-label="`Ações de ${item.name}`" />
    </UDropdownMenu>
  </li>
</template>
