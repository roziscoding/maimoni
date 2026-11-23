<script setup lang="ts">
import type { Currency, LiveRates, Month, MonthSummary, UpdateMonth } from '@maimoni/shared'

const props = defineProps<{
  month: Month
  /** Live rates quoted against the month's main currency. */
  rates: LiveRates | null
  error: string | null
  summary: MonthSummary
  refreshing: boolean
}>()

const emit = defineEmits<{
  update: [patch: UpdateMonth]
  retry: []
}>()

const sources: Record<LiveRates['source'], string> = {
  'frankfurter': 'Frankfurter (BCE)',
  'open-er-api': 'Open Exchange Rates',
  'cache': 'último valor salvo',
}

/** One row per currency the month converts from: the rate in use, the live one, and whether it is locked. */
const rows = computed(() => props.summary.conversions.map(conversion => ({
  ...conversion,
  live: props.rates?.rates[conversion.currency] ?? null,
})))

/** Freezes a currency's rate at the live value, leaving the other locked rates as they are. */
function lock(currency: Currency, rate: number) {
  emit('update', { lockedRates: { ...props.month.lockedRates, [currency]: rate } })
}

function unlock(currency: Currency) {
  const { [currency]: _unlocked, ...rest } = props.month.lockedRates
  emit('update', { lockedRates: rest })
}
</script>

<template>
  <section aria-labelledby="rate-title" class="divide-y divide-default rounded-xl border border-default">
    <div class="space-y-1 p-4">
      <h2 id="rate-title" class="text-sm font-medium text-muted">
        Cotações
      </h2>
      <p class="text-xs text-muted">
        Quanto vale {{ formatMoney(1, summary.main) }} em cada moeda do mês.
      </p>
    </div>

    <div v-for="row in rows" :key="row.currency" class="space-y-3 p-4">
      <div class="flex items-center justify-between gap-2">
        <h3 class="text-sm font-medium text-highlighted">
          {{ currencyName(row.currency) }}
        </h3>
        <UBadge v-if="row.rateLocked" color="neutral" variant="subtle" size="sm" icon="i-lucide-lock" label="travada" />
        <UBadge v-else-if="rates?.stale" color="warning" variant="subtle" size="sm" icon="i-lucide-clock-alert" label="desatualizada" />
        <UBadge v-else-if="row.live" color="neutral" variant="outline" size="sm" icon="i-lucide-radio" label="ao vivo" />
      </div>

      <p class="money text-3xl font-semibold text-highlighted">
        {{ formatRate(row.rate, row.currency) }}
      </p>

      <p v-if="row.rateLocked && row.live" class="text-xs text-muted">
        Ao vivo agora: <span class="money text-toned">{{ formatRate(row.live, row.currency) }}</span>.
      </p>
      <p v-else-if="!row.rate" class="text-xs text-warning">
        Nenhuma cotação disponível agora.
      </p>

      <UButton
        v-if="row.rateLocked"
        icon="i-lucide-lock-open"
        label="Usar cotação ao vivo"
        color="neutral"
        variant="subtle"
        size="sm"
        block
        @click="unlock(row.currency)"
      />
      <UButton
        v-else-if="row.live"
        icon="i-lucide-lock"
        :label="`Travar em ${formatRate(row.live, row.currency)}`"
        color="neutral"
        variant="subtle"
        size="sm"
        block
        @click="lock(row.currency, row.live)"
      />
      <UButton
        v-else
        icon="i-lucide-refresh-cw"
        label="Tentar novamente"
        color="neutral"
        variant="subtle"
        size="sm"
        block
        :loading="refreshing"
        @click="emit('retry')"
      />
    </div>

    <div v-if="rates || error" class="space-y-1 p-4 text-xs">
      <p v-if="rates" class="text-muted">
        Fonte: {{ sources[rates.source] }}, {{ formatDateTime(rates.fetchedAt) }}.
      </p>
      <p v-if="error" class="text-error">
        {{ rates ? 'Falha ao atualizar' : 'Motivo' }}: {{ error }}
      </p>
    </div>
  </section>
</template>
