<script setup lang="ts">
import type { DailySpend, MonthSummary } from '@maimoni/shared'
import { spendInMain } from '@maimoni/shared'

const props = defineProps<{
  /** The month's summary: the allowance, and the rates that size a spend in another currency by its cost. */
  summary: MonthSummary
  /** The open day's spending, in the order it was recorded. */
  spends: DailySpend[]
  /** Whether the month has more than one currency, and so equivalents in the others to show. */
  exchange: boolean
}>()

const allowance = computed(() => props.summary.allowance)
const main = computed(() => props.summary.main)
const budget = computed(() => allowance.value.amount ?? 0)
const remaining = computed(() => allowance.value.remaining ?? 0)
const over = computed(() => remaining.value < 0)
/** What is left today in each other currency of the month that has a rate. */
const equivalents = computed(() => props.exchange
  ? props.summary.conversions.filter(conversion => conversion.rate).map(conversion => formatMoney(remaining.value * conversion.rate!, conversion.currency))
  : [])

/** Each spend is a slice of the day's budget; past the budget the bar is full and turns red. */
const segments = computed(() => {
  if (budget.value <= 0)
    return []
  let used = 0
  return props.spends.map((spend) => {
    const value = spendInMain(spend, props.summary) ?? 0
    const width = Math.max(0, Math.min(value, budget.value - used)) / budget.value * 100
    used += Math.max(0, value)
    return { id: spend.id, width, label: `${spend.note ?? 'Gasto'}: ${formatMoney(spend.amount, spend.currency)}` }
  }).filter(segment => segment.width > 0)
})
</script>

<template>
  <section aria-labelledby="day-hero-title" class="space-y-5">
    <h2 id="day-hero-title" class="sr-only">
      Quanto ainda dá para gastar hoje
    </h2>

    <div class="space-y-1">
      <p
        class="money text-6xl font-semibold leading-none tracking-tight sm:text-8xl"
        :class="over ? 'text-error' : 'text-highlighted'"
      >
        {{ formatMoney(remaining, main) }}
      </p>
      <p class="text-sm text-muted">
        <template v-if="over">
          Passou <span class="money">{{ formatMoney(-remaining, main) }}</span> do valor de hoje.
        </template>
        <template v-else-if="allowance.spentToday > 0">
          Sobrando de <span class="money">{{ formatMoney(budget, main) }}</span> para hoje.
        </template>
        <template v-else>
          Para gastar hoje.
        </template>
        <span v-for="equivalent in equivalents" :key="equivalent" class="money"> ≈ {{ equivalent }}</span>
      </p>
    </div>

    <div
      class="flex h-3 w-full gap-px overflow-hidden rounded-full bg-accented"
      :class="{ 'ring-2 ring-error/60 ring-offset-2 ring-offset-default': over }"
      role="img"
      :aria-label="`${formatMoney(allowance.spentToday, main)} gastos de ${formatMoney(budget, main)}`"
    >
      <div
        v-for="segment in segments"
        :key="segment.id"
        class="h-full transition-[width] duration-300 motion-reduce:transition-none"
        :class="over ? 'bg-error' : 'bg-inverted'"
        :style="{ width: `${segment.width}%` }"
        :title="segment.label"
      />
    </div>
  </section>
</template>
