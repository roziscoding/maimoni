<script setup lang="ts">
import type { MonthSummary } from '@maimoni/shared'
import { daysInMonth, monthPhase } from '@maimoni/shared'

const props = defineProps<{
  year: number
  month: number
  summary: MonthSummary
  /** Whether the month has more than one currency, and so rates and equivalents in the others to show. */
  exchange: boolean
}>()

const today = new Date()
const phase = computed(() => monthPhase(props.year, props.month, today))
const total = computed(() => daysInMonth(props.year, props.month))
const todayNumber = computed(() => phase.value === 'current' ? today.getDate() : null)

/** One tick per day: spent days fade, today stands out, weekends are shorter so the weeks read at a glance. */
const days = computed(() => Array.from({ length: total.value }, (_, index) => {
  const day = index + 1
  const weekday = new Date(props.year, props.month - 1, day).getDay()
  const spent = phase.value === 'past' || (todayNumber.value !== null && day < todayNumber.value)
  return { day, spent, today: day === todayNumber.value, weekend: weekday === 0 || weekday === 6 }
}))

const allowance = computed(() => props.summary.allowance)
// Past months show what was left over; open months show the daily budget.
const headline = computed(() => phase.value === 'past' ? props.summary.net : allowance.value.amount)
/** The daily budget in each other currency of the month that has a rate. */
const equivalents = computed(() => {
  const amount = allowance.value.amount
  if (amount === null)
    return []
  return props.summary.conversions.filter(conversion => conversion.rate).map(conversion => formatMoney(amount * conversion.rate!, conversion.currency))
})
</script>

<template>
  <section aria-labelledby="hero-title" class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-x-10 gap-y-4">
      <div>
        <p id="hero-title" class="text-sm font-medium text-muted">
          {{ phase === 'past' ? 'Mês encerrado, sobrou' : 'Por dia' }}
        </p>
        <p
          class="money mt-1 text-5xl font-semibold tracking-tight sm:text-7xl"
          :class="(headline ?? 0) < 0 ? 'text-error' : 'text-highlighted'"
        >
          {{ formatMoney(headline, summary.main) }}
        </p>
      </div>

      <div class="space-y-1 pb-1 text-sm sm:text-right">
        <p v-if="phase === 'past'" class="text-muted">
          {{ exchange ? `Líquido final em ${currencyPlural(summary.main).toLowerCase()}` : 'Líquido final' }}
        </p>
        <p v-else-if="allowance.amount === null" class="text-muted">
          Sem cotação, não dá para calcular o valor por dia.
        </p>
        <template v-else>
          <template v-if="exchange">
            <p v-for="equivalent in equivalents" :key="equivalent" class="money text-base text-default">
              ≈ {{ equivalent }} por dia
            </p>
          </template>
          <p class="text-muted">
            <template v-if="phase === 'current'">
              {{ allowance.days === 1 ? 'Último dia do mês' : `${allowance.days} dias restantes, contando hoje` }}
            </template>
            <template v-else>
              Mês futuro, dividido pelos {{ allowance.days }} dias
            </template>
          </p>
        </template>
      </div>
    </div>

    <figure :aria-label="`${allowance.days} de ${total} dias restantes`">
      <div class="flex h-9 items-end gap-[3px]">
        <span
          v-for="day in days"
          :key="day.day"
          class="flex-1 rounded-[2px]"
          :class="[
            day.today ? 'h-9 bg-inverted' : day.weekend ? 'h-5' : 'h-7',
            !day.today && (day.spent ? 'bg-accented' : 'bg-inverted/55'),
          ]"
          :title="`Dia ${day.day}`"
        />
      </div>
      <figcaption class="money relative mt-1.5 flex justify-between text-xs text-dimmed" aria-hidden="true">
        <span>1</span>
        <span
          v-if="todayNumber"
          class="absolute -translate-x-1/2 font-medium text-highlighted"
          :style="{ left: `${((todayNumber - 0.5) / total) * 100}%` }"
        >hoje</span>
        <span>{{ total }}</span>
      </figcaption>
    </figure>
  </section>
</template>
