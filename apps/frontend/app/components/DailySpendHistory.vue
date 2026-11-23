<script setup lang="ts">
import type { DailySpend, DayResult, MonthListEntry } from '@maimoni/shared'
import { dayResults, groupDailySpends, currencies as knownCurrencies, spendInMain } from '@maimoni/shared'

const route = useRoute()
const view = computed(() => route.query.view === 'spends' ? 'spends' : 'calendar')
const now = new Date()
/** `?mes=2026-10`; defaults to the current month. */
const [year, month] = (() => {
  const match = /^(\d{4})-(\d{1,2})$/.exec(String(route.query.mes ?? ''))
  return match ? [Number(match[1]), Number(match[2])] : [now.getFullYear(), now.getMonth() + 1]
})() as [number, number]

const { data, error, summary, addSpend, updateSpend, removeSpend } = await useMonth(year, month)
const { data: months } = useNuxtData<MonthListEntry[]>('months')

const monthOptions = computed(() => (months.value ?? []).map(entry => ({
  label: monthLabel(entry.year, entry.month),
  value: `${entry.year}-${entry.month}`,
})))
const selectedMonth = computed({
  get: () => `${year}-${month}`,
  set: value => navigateTo({ query: { mes: value, view: view.value } }),
})

const days = computed(() => data.value && summary.value ? dayResults(data.value.month, summary.value, data.value.spends) : [])
const closed = computed(() => days.value.filter(day => day.state === 'closed' && day.result !== null))
const withinBudget = computed(() => closed.value.filter(day => (day.result ?? 0) >= 0).length)
/**
 * Closed days against the month's original plan (net ÷ days in month each). Summing the daily
 * results would double count: what's left on one day rolls into the next days' budgets.
 */
const balance = computed(() => {
  if (!summary.value || !days.value.length)
    return 0
  const planned = closed.value.length * (summary.value.net ?? 0) / days.value.length
  return planned - closed.value.reduce((sum, day) => sum + day.spent, 0)
})
/** Months before daily tracking existed have nothing to show day by day. */
const untracked = computed(() => !data.value?.spends.length && summary.value?.allowance.activeDay === null)

/** Monday first, like Spanish calendars. */
const weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']
const leadingBlanks = (new Date(year, month - 1, 1).getDay() + 6) % 7

/** Opens on the open day, or on the last day with spending for months that are done. */
const selected = ref<number>(summary.value?.allowance.activeDay
  ?? data.value?.spends.at(-1)?.day
  ?? 1)
const selectedDay = computed(() => days.value.find(day => day.day === selected.value))
const selectedSpends = computed(() => data.value?.spends.filter(spend => spend.day === selected.value) ?? [])
const spendGroups = computed(() => groupDailySpends(data.value?.spends ?? []))

/** The currency the month is worked out in; every figure here is in it. */
const main = computed(() => summary.value?.main ?? knownCurrencies[0])
/** A spend's cost to the allowance (one in another currency is converted the way the allowance counts it). */
const costOf = (spend: DailySpend) => summary.value ? spendInMain(spend, summary.value) : null

const signed = (value: number) => `${value >= 0 ? '+' : '−'}${formatMoney(Math.abs(value), main.value)}`
/** Compact form for narrow cells: `+12` / `−8`. */
const compact = (value: number) => `${value >= 0 ? '+' : '−'}${Math.round(Math.abs(value))}`

/**
 * The result as a bar: what was left fills green from the left (full when nothing was spent),
 * what went over fills red from the right (full at a whole day's budget over).
 */
function bar(day: DayResult) {
  if (day.result === null || !day.budget)
    return null
  return {
    over: day.result < 0,
    width: `${Math.min(1, Math.abs(day.result) / day.budget) * 100}%`,
  }
}

function cellLabel(day: DayResult) {
  if (day.state === 'upcoming')
    return `Dia ${day.day}: ainda não chegou`
  if (day.result === null)
    return `Dia ${day.day}: sem cotação para calcular`
  return day.state === 'open'
    ? `Dia ${day.day}, aberto: restam ${formatMoney(day.result, main.value)}`
    : `Dia ${day.day}: ${signed(day.result)}`
}
</script>

<template>
  <section class="mx-auto mt-10 w-full max-w-4xl space-y-6 border-t border-default pt-8">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <DailySpendTabs :view="view" />
      <USelect v-if="monthOptions.length" v-model="selectedMonth" :items="monthOptions" aria-label="Mês" class="w-40 sm:w-44" />
    </div>

    <UEmpty
      v-if="data && summary && untracked"
      icon="i-lucide-calendar-off"
      :title="`Nenhum gasto do dia a dia em ${monthName(month).toLowerCase()}`"
      description="O calendário mostra os dias de meses em que os gastos foram lançados em Hoje."
      variant="naked"
      class="py-10"
    />

      <div v-else-if="data && summary" class="mx-auto w-full max-w-4xl space-y-6 py-2">
        <div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-2">
          <div>
            <h2 class="text-2xl font-semibold text-highlighted">
              {{ monthLabel(year, month) }}
            </h2>
            <p class="text-sm text-muted">
              <template v-if="closed.length">
                {{ withinBudget }} de {{ closed.length }} {{ closed.length === 1 ? 'dia fechado' : 'dias fechados' }} dentro do valor do dia.
              </template>
              <template v-else>
                Nenhum dia fechado ainda.
              </template>
            </p>
          </div>
          <div v-if="closed.length" class="sm:text-right">
            <p class="money text-2xl font-semibold" :class="balance >= 0 ? 'text-success' : 'text-error'">
              {{ signed(balance) }}
            </p>
            <p class="text-sm text-muted">
              {{ balance >= 0 ? 'sobrou' : 'passou' }} nos dias fechados
            </p>
          </div>
        </div>

        <template v-if="view === 'calendar'">
          <div class="grid grid-cols-7 gap-1 sm:gap-1.5" role="grid" :aria-label="monthLabel(year, month)">
            <div v-for="weekday in weekdays" :key="weekday" class="pb-1 text-center text-xs text-muted" role="columnheader">
              {{ weekday }}
            </div>
            <div v-for="blank in leadingBlanks" :key="`blank-${blank}`" aria-hidden="true" />

            <button
              v-for="day in days"
              :key="day.day"
              type="button"
              role="gridcell"
              :aria-selected="selected === day.day"
              :aria-label="cellLabel(day)"
              class="relative flex aspect-square flex-col overflow-hidden rounded-md border p-1 text-left transition-colors outline-none focus-visible:ring-2 focus-visible:ring-inverted sm:aspect-[4/3] sm:p-2"
              :class="[
                day.state === 'open' ? 'border-inverted' : 'border-default',
                day.state === 'upcoming' ? 'opacity-50' : 'hover:border-accented',
                selected === day.day && 'ring-2 ring-inverted',
              ]"
              @click="selected = day.day"
            >
              <span class="text-xs" :class="day.state === 'open' ? 'font-semibold text-highlighted' : 'text-muted'">
                {{ day.day }}
              </span>

              <span class="mt-auto">
                <template v-if="day.state === 'closed' && day.result !== null">
                  <span class="money block text-[11px] font-semibold sm:text-sm" :class="day.result >= 0 ? 'text-success' : 'text-error'">
                    <span class="sm:hidden">{{ compact(day.result) }}</span>
                    <span class="hidden sm:inline">{{ signed(day.result) }}</span>
                  </span>
                  <span class="money hidden text-[11px] text-dimmed sm:block">
                    {{ day.spent ? `gasto ${formatMoney(day.spent, main)}` : 'sem gastos' }}
                  </span>
                </template>
                <template v-else-if="day.state === 'open' && day.result !== null">
                  <span class="hidden text-[11px] text-muted sm:block">aberto, restam</span>
                  <span class="money block text-[11px] font-semibold sm:text-sm" :class="day.result >= 0 ? 'text-highlighted' : 'text-error'">
                    <span class="sm:hidden">{{ compact(day.result).replace('+', '') }}</span>
                    <span class="hidden sm:inline">{{ formatMoney(day.result, main) }}</span>
                  </span>
                </template>
                <span v-else-if="day.state === 'upcoming' && day.budget !== null" class="money hidden text-[11px] text-dimmed sm:block">
                  {{ formatMoney(day.budget, main) }}
                </span>

                <span
                  v-if="day.state !== 'upcoming' && bar(day)"
                  aria-hidden="true"
                  class="relative mt-1 block h-1 w-full overflow-hidden rounded-full bg-accented sm:mt-1.5 sm:h-1.5"
                >
                  <span
                    class="absolute inset-y-0 rounded-full"
                    :class="[
                      bar(day)!.over ? 'end-0 bg-error' : 'start-0',
                      !bar(day)!.over && (day.state === 'open' ? 'bg-inverted' : 'bg-success'),
                    ]"
                    :style="{ width: bar(day)!.width }"
                  />
                </span>
              </span>
            </button>
          </div>

          <section v-if="selectedDay" aria-live="polite" class="space-y-3 rounded-xl border border-default p-4">
            <div class="flex flex-wrap items-baseline justify-between gap-2">
              <h3 class="font-semibold text-highlighted">
                {{ dayLabel(year, month, selectedDay.day) }}
              </h3>
              <dl v-if="selectedDay.state !== 'upcoming' && selectedDay.result !== null" class="flex gap-5 text-sm">
                <div>
                  <dt class="text-xs text-muted">
                    Valor do dia
                  </dt>
                  <dd class="money">
                    {{ formatMoney(selectedDay.budget, main) }}
                  </dd>
                </div>
                <div>
                  <dt class="text-xs text-muted">
                    Gasto
                  </dt>
                  <dd class="money">
                    {{ formatMoney(selectedDay.spent, main) }}
                  </dd>
                </div>
                <div>
                  <dt class="text-xs text-muted">
                    {{ selectedDay.state === 'open' ? 'Restam' : 'Resultado' }}
                  </dt>
                  <dd class="money font-semibold" :class="selectedDay.result >= 0 ? 'text-success' : 'text-error'">
                    {{ selectedDay.state === 'open' ? formatMoney(selectedDay.result, main) : signed(selectedDay.result) }}
                  </dd>
                </div>
              </dl>
            </div>

            <SpendForm
              v-if="selectedDay.state === 'closed'"
              :key="selectedDay.day"
              :day="selectedDay.day"
              :create="addSpend"
            />

            <ul v-if="selectedSpends.length" class="divide-y divide-default">
              <SpendRow
                v-for="spend in selectedSpends"
                :key="spend.id"
                :spend="spend"
                :main="main"
                :cost="costOf(spend)"
                @update="updateSpend(spend.id, $event)"
                @remove="removeSpend(spend.id)"
              />
            </ul>
            <p v-else-if="selectedDay.state === 'upcoming'" class="text-sm text-muted">
              Ainda não chegou.
              <template v-if="selectedDay.budget !== null">
                Se o dia aberto fechasse agora, este dia teria {{ formatMoney(selectedDay.budget, main) }}.
              </template>
            </p>
            <p v-else class="text-sm text-muted">
              Nenhum gasto neste dia.
            </p>
          </section>
        </template>

        <div v-else class="space-y-4">
          <section
            v-for="group in spendGroups"
            :key="group.day"
            class="rounded-xl border border-default px-4 py-3"
          >
            <div class="flex items-center justify-between gap-3 pb-2">
              <h3 class="font-semibold text-highlighted">
                {{ dayLabel(year, month, group.day) }}
              </h3>
              <span class="text-xs text-muted">
                {{ group.spends.length }} {{ group.spends.length === 1 ? 'gasto' : 'gastos' }}
              </span>
            </div>
            <ul class="divide-y divide-default">
              <SpendRow
                v-for="spend in group.spends"
                :key="spend.id"
                :spend="spend"
                :main="main"
                :cost="costOf(spend)"
                @update="updateSpend(spend.id, $event)"
                @remove="removeSpend(spend.id)"
              />
            </ul>
          </section>

          <UEmpty
            v-if="!spendGroups.length"
            icon="i-lucide-receipt-text"
            title="Nenhum gasto neste mês"
            description="Os gastos lançados no dia a dia aparecerão aqui."
            variant="naked"
          />
        </div>
      </div>

    <UEmpty
      v-else-if="error"
      icon="i-lucide-calendar-x"
      :title="error.statusCode === 404 ? `${monthLabel(year, month)} não existe` : 'Não foi possível carregar o mês'"
      :description="error.statusCode === 404 ? undefined : errorMessage(error)"
      variant="naked"
      class="py-10"
    />
  </section>
</template>
