<script setup lang="ts">
import type { MonthItem, UpdateMonthItem } from '@maimoni/shared'
import type { DropdownMenuItem } from '@nuxt/ui'

const props = defineProps<{
  item: MonthItem
}>()

const emit = defineEmits<{
  update: [patch: UpdateMonthItem]
  remove: []
  promote: []
}>()

const isIncome = computed(() => props.item.kind === 'income')

function renameTo(value: string) {
  const name = value.trim()
  if (name && name !== props.item.name)
    emit('update', { name })
}

const menu = computed<DropdownMenuItem[][]>(() => [
  [
    ...(props.item.needsReview
      ? [{ label: 'Confirmar valor', icon: 'i-lucide-check', onSelect: () => emit('update', { needsReview: false }) }]
      : []),
    {
      label: props.item.templateItemId ? 'Atualizar no template' : 'Salvar no template',
      icon: 'i-lucide-layout-template',
      onSelect: () => emit('promote'),
    },
    {
      label: isIncome.value ? 'Mover para saídas' : 'Mover para entradas',
      icon: isIncome.value ? 'i-lucide-arrow-up-right' : 'i-lucide-arrow-down-left',
      onSelect: () => emit('update', { kind: isIncome.value ? 'expense' : 'income' }),
    },
  ],
  [{ label: 'Excluir', icon: 'i-lucide-trash-2', color: 'error', onSelect: () => emit('remove') }],
])
</script>

<template>
  <li
    class="group grid grid-cols-[auto_minmax(0,1fr)_minmax(7.5rem,10rem)_auto] items-center gap-x-1 rounded-md px-1 py-0.5 transition-colors hover:bg-elevated/60 focus-within:bg-elevated/60"
    :class="{ 'opacity-60 hover:opacity-100 focus-within:opacity-100': item.paid }"
  >
    <UCheckbox
      :model-value="item.paid"
      :aria-label="`${isIncome ? 'Recebido' : 'Pago'}: ${item.name}`"
      class="px-2"
      @update:model-value="emit('update', { paid: $event === true })"
    />

    <div class="flex min-w-0 items-center gap-1.5">
      <UInput
        :model-value="item.name"
        :aria-label="`Nome de ${item.name}`"
        variant="ghost"
        class="min-w-0 flex-1"
        :ui="{ base: item.paid ? 'line-through decoration-muted' : '' }"
        @change="renameTo(($event.target as HTMLInputElement).value)"
        @keydown.enter="($event.target as HTMLInputElement).blur()"
      />
      <UTooltip v-if="item.needsReview" text="Valor estimado a partir do template. Confirme ou edite para este mês.">
        <UButton
          size="xs"
          color="warning"
          variant="soft"
          icon="i-lucide-circle-dot"
          label="confirmar"
          :aria-label="`Confirmar valor de ${item.name}`"
          class="shrink-0"
          @click="emit('update', { needsReview: false })"
        />
      </UTooltip>
    </div>

    <AmountInput
      :amount="item.amount"
      :expression="item.expression"
      :currency="item.currency"
      :label="`Valor de ${item.name}`"
      :highlight="item.amount === null"
      @commit="emit('update', $event)"
    />

    <UDropdownMenu :items="menu" :content="{ align: 'end' }">
      <UButton
        icon="i-lucide-ellipsis"
        color="neutral"
        variant="ghost"
        size="sm"
        :aria-label="`Ações de ${item.name}`"
        class="opacity-100 sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100 data-[state=open]:opacity-100"
      />
    </UDropdownMenu>
  </li>
</template>
