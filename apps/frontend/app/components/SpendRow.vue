<script setup lang="ts">
import type { DailySpend, UpdateDailySpend } from '@maimoni/shared'

const props = defineProps<{
  spend: DailySpend
  /** What the spend costs the EUR allowance; shown next to BRL spends. */
  eur: number | null
}>()

const emit = defineEmits<{
  update: [patch: UpdateDailySpend]
  remove: []
}>()

const name = computed(() => props.spend.note ?? 'gasto')

function editNote(value: string) {
  const note = value.trim() || null
  if (note !== props.spend.note)
    emit('update', { note })
}
</script>

<template>
  <li class="flex items-center gap-2 py-1">
    <UInput
      :model-value="spend.note ?? ''"
      placeholder="Gasto"
      variant="ghost"
      :aria-label="`Descrição de ${name}`"
      class="min-w-0 flex-1"
      @change="editNote(($event.target as HTMLInputElement).value)"
    />
    <div class="flex w-28 shrink-0 flex-col items-end sm:w-36">
      <AmountInput
        :amount="spend.amount"
        :expression="spend.expression"
        :currency="spend.currency"
        :label="`Valor de ${name}`"
        class="w-full"
        @commit="$event.amount !== null && emit('update', { amount: $event.amount, expression: $event.expression })"
      />
      <span v-if="spend.currency === 'BRL'" class="money pe-2.5 text-xs text-dimmed">
        ≈ {{ formatMoney(eur, 'EUR') }}
      </span>
    </div>
    <UButton
      icon="i-lucide-x"
      color="neutral"
      variant="ghost"
      size="sm"
      :aria-label="`Apagar ${name}`"
      @click="emit('remove')"
    />
  </li>
</template>
