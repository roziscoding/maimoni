<script setup lang="ts">
import type { Currency, CurrencyConversion, CurrencyTotals, MonthSummary } from '@maimoni/shared'

const props = defineProps<{
  summary: MonthSummary
  /** The currencies to show a lane for. The month's main one is always shown, last. */
  currencies: Currency[]
  /** Always stack the lanes like a receipt, even on wide screens (for narrow columns). */
  compact?: boolean
}>()

interface Cell {
  op: string
  label: string
  value: number | null
  tone?: 'result' | 'final'
}

interface Lane {
  currency: Currency
  cells: Cell[]
  /** How what is left in the lane's currency becomes main currency; absent on the main lane. */
  conversion?: CurrencyConversion
}

const EMPTY: CurrencyTotals = { income: 0, expenses: 0, net: 0, paid: 0, pending: 0, unresolved: 0 }

/**
 * One lane per other currency, each ending in what is left in it, then the main currency's lane,
 * which takes in what the others were converted into.
 */
const lanes = computed<Lane[]>(() => {
  const { main, totals, conversions, converted, net } = props.summary
  const others: Lane[] = props.currencies.filter(currency => currency !== main).map((currency) => {
    const own = totals[currency] ?? EMPTY
    return {
      currency,
      cells: [
        { op: '', label: 'Entrada', value: own.income },
        { op: '−', label: 'Saída', value: own.expenses },
        { op: '=', label: `Em ${currencyPlural(currency).toLowerCase()}`, value: own.net, tone: 'result' },
      ],
      conversion: conversions.find(conversion => conversion.currency === currency),
    }
  })
  const own = totals[main] ?? EMPTY
  return [
    ...others,
    {
      currency: main,
      cells: [
        { op: '', label: 'Entrada', value: own.income },
        // Only where there is another currency to convert from.
        ...(others.length ? [{ op: '+', label: 'Convertido', value: converted }] : []),
        { op: '−', label: 'Saída', value: own.expenses },
        { op: '=', label: 'Líquido', value: net, tone: 'final' as const },
      ],
    },
  ]
})

function valueClass(cell: Cell) {
  if (cell.value !== null && cell.value < 0)
    return 'text-error'
  if (cell.tone === 'final' && cell.value !== null && cell.value > 0)
    return 'text-success'
  return cell.tone ? 'text-highlighted' : 'text-default'
}
</script>

<template>
  <section :aria-label="lanes.length > 1 ? 'Fluxo do mês: cada moeda, a conversão e o líquido' : 'Fluxo do mês: entrada, saída e líquido'" class="overflow-hidden rounded-xl border border-default">
    <template v-for="lane in lanes" :key="lane.currency">
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

      <!-- What is left in the lane's currency, on its way to the main one. -->
      <div
        v-if="lane.conversion"
        class="border-y border-dashed border-accented bg-muted px-4 py-2.5 text-sm"
      >
        <div v-if="lane.conversion.net !== 0" class="flex flex-wrap items-center gap-x-2 gap-y-1">
          <UIcon name="i-lucide-sparkles" class="size-4 text-muted" aria-hidden="true" />
          <span class="font-medium text-highlighted">Conversão</span>
          <span class="money text-toned">{{ formatMoney(lane.conversion.net, lane.currency) }}</span>
          <span class="money text-toned">
            ÷ {{ formatRate(lane.conversion.rate, lane.currency) }}
            <UIcon v-if="lane.conversion.rateLocked" name="i-lucide-lock" class="size-3 align-[-1px] text-muted" aria-label="cotação travada" />
          </span>
          <span class="money ms-auto font-medium text-highlighted">= {{ formatMoney(lane.conversion.converted, summary.main) }}</span>
        </div>
        <div v-else class="flex items-center gap-2 text-muted">
          <UIcon name="i-lucide-arrow-down" class="size-4" aria-hidden="true" />
          Nada a converter
        </div>
      </div>
    </template>
  </section>
</template>
