<script setup lang="ts">
import type { Currency, MonthSummary } from '@maimoni/shared'

const props = defineProps<{
  summary: MonthSummary
  /** Always stack the lanes like a receipt, even on wide screens (for narrow columns). */
  compact?: boolean
}>()

interface Cell {
  op: string
  label: string
  value: number | null
  tone?: 'result' | 'final'
}

const lanes = computed<{ currency: Currency, cells: Cell[] }[]>(() => [
  {
    currency: 'BRL',
    cells: [
      { op: '', label: 'Entrada', value: props.summary.brl.income },
      { op: '−', label: 'Despesas', value: props.summary.brl.expenses },
      { op: '−', label: 'Conversão', value: props.summary.transfer.realized.convertedBrl },
      { op: '−', label: 'Taxa Wise', value: props.summary.transfer.realized.feeBrl },
      { op: '=', label: 'Em reais', value: props.summary.transfer.remainingBrl, tone: 'result' },
    ],
  },
  {
    currency: 'EUR',
    cells: [
      { op: '', label: 'Entrada', value: props.summary.transfer.eur === null ? null : props.summary.eur.income },
      { op: '−', label: 'Saída', value: props.summary.eur.expenses },
      { op: '=', label: 'Líquido', value: props.summary.transfer.eur === null ? null : props.summary.eur.net, tone: 'final' },
    ],
  },
])

const transfer = computed(() => props.summary.transfer)

function valueClass(cell: Cell) {
  if (cell.value !== null && cell.value < 0)
    return 'text-error'
  if (cell.tone === 'final' && cell.value !== null && cell.value > 0)
    return 'text-success'
  return cell.tone ? 'text-highlighted' : 'text-default'
}
</script>

<template>
  <section aria-label="Fluxo do mês: reais, transferência pela Wise e euros" class="overflow-hidden rounded-xl border border-default">
    <template v-for="(lane, laneIndex) in lanes" :key="lane.currency">
      <div class="flex flex-col px-4 py-3" :class="{ 'sm:flex-row sm:items-stretch sm:py-4': !compact }">
        <template v-for="(cell, index) in lane.cells" :key="cell.label">
          <span
            v-if="index > 0 && !compact"
            aria-hidden="true"
            class="money hidden select-none items-center px-2 text-2xl font-extralight text-dimmed sm:flex lg:px-4"
          >{{ cell.op }}</span>
          <div
            class="flex items-baseline justify-between gap-3 py-1"
            :class="[
              { 'sm:block sm:flex-1 sm:py-0': !compact },
              cell.tone && ['mt-1 border-t border-dashed border-default pt-2', { 'sm:mt-0 sm:border-0 sm:pt-0': !compact }],
            ]"
          >
            <p class="text-sm text-muted">
              <span v-if="cell.op" aria-hidden="true" class="money me-1 inline-block w-3" :class="{ 'sm:hidden': !compact }">{{ cell.op }}</span>
              {{ cell.label }}
            </p>
            <p
              class="money text-lg"
              :class="[valueClass(cell), cell.tone ? 'font-semibold' : 'font-normal', { 'sm:mt-0.5 sm:text-xl xl:text-2xl': !compact }]"
            >
              {{ formatMoney(cell.value, lane.currency) }}
            </p>
          </div>
        </template>
      </div>

      <div
        v-if="laneIndex === 0"
        class="space-y-1.5 border-y border-dashed border-accented bg-muted px-4 py-2.5 text-sm"
      >
        <div v-if="transfer.realized.sentBrl > 0" class="flex flex-wrap items-center gap-x-2 gap-y-1">
          <UIcon name="i-lucide-circle-check" class="size-4 text-success" aria-hidden="true" />
          <span class="font-medium text-highlighted">Realizado</span>
          <span class="money text-toned">{{ formatMoney(transfer.realized.sentBrl, 'BRL') }}</span>
          <span class="text-muted">incluindo {{ formatMoney(transfer.realized.feeBrl, 'BRL') }} de taxa</span>
          <span class="money ms-auto font-medium text-highlighted">= {{ formatMoney(transfer.realized.receivedEur, 'EUR') }}</span>
        </div>
        <div v-if="transfer.projected.sentBrl > 0" class="flex flex-wrap items-center gap-x-2 gap-y-1">
          <UIcon name="i-lucide-sparkles" class="size-4 text-muted" aria-hidden="true" />
          <span class="font-medium text-highlighted">Projetado</span>
          <span class="money text-toned">{{ formatMoney(transfer.projected.sentBrl, 'BRL') }}</span>
          <span class="money text-toned">− {{ formatMoney(transfer.projected.feeBrl, 'BRL') }}</span>
          <span class="money text-toned">
            ÷ {{ formatRate(transfer.rate) }}
            <UIcon v-if="transfer.rateLocked" name="i-lucide-lock" class="size-3 align-[-1px] text-muted" aria-label="cotação travada" />
          </span>
          <span class="money ms-auto font-medium text-highlighted">= {{ formatMoney(transfer.projected.eur, 'EUR') }}</span>
        </div>
        <div v-if="transfer.realized.sentBrl === 0 && transfer.projected.sentBrl === 0" class="flex items-center gap-2 text-muted">
          <UIcon name="i-lucide-arrow-down" class="size-4" aria-hidden="true" />
          Nada a converter
        </div>
      </div>
    </template>
  </section>
</template>
