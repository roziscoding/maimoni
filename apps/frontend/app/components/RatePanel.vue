<script setup lang="ts">
import type { LiveRate, Month, MonthSummary, UpdateMonth } from '@maimoni/shared'

const props = defineProps<{
  month: Month
  rate: LiveRate | null
  error: string | null
  summary: MonthSummary
  refreshing: boolean
}>()

const emit = defineEmits<{
  update: [patch: UpdateMonth]
  retry: []
}>()

const sources: Record<LiveRate['source'], string> = {
  'frankfurter': 'Frankfurter (BCE)',
  'open-er-api': 'Open Exchange Rates',
  'cache': 'último valor salvo',
}

const locked = computed(() => props.month.exchangeRate !== null)
</script>

<template>
  <section aria-labelledby="rate-title" class="divide-y divide-default rounded-xl border border-default">
    <div class="space-y-3 p-4">
      <div class="flex items-center justify-between gap-2">
        <h2 id="rate-title" class="text-sm font-medium text-muted">
          Preço do euro
        </h2>
        <UBadge v-if="locked" color="neutral" variant="subtle" size="sm" icon="i-lucide-lock" label="travado" />
        <UBadge v-else-if="rate?.stale" color="warning" variant="subtle" size="sm" icon="i-lucide-clock-alert" label="desatualizado" />
        <UBadge v-else-if="rate" color="neutral" variant="outline" size="sm" icon="i-lucide-radio" label="ao vivo" />
      </div>

      <p class="money text-3xl font-semibold text-highlighted">
        {{ formatRate(summary.transfer.rate) }}
      </p>

      <p v-if="rate" class="text-xs text-muted">
        <template v-if="locked">
          Ao vivo agora: <span class="money text-toned">{{ formatRate(rate.rate) }}</span>.
        </template>
        Fonte: {{ sources[rate.source] }}, {{ formatDateTime(rate.fetchedAt) }}.
      </p>
      <p v-else class="text-xs text-warning">
        Nenhuma cotação disponível agora. Trave um valor para calcular o mês.
      </p>
      <p v-if="error" class="text-xs text-error">
        {{ rate ? 'Falha ao atualizar' : 'Motivo' }}: {{ error }}
      </p>

      <UButton
        v-if="locked"
        icon="i-lucide-lock-open"
        label="Usar cotação ao vivo"
        color="neutral"
        variant="subtle"
        size="sm"
        block
        @click="emit('update', { exchangeRate: null })"
      />
      <UButton
        v-else-if="rate"
        icon="i-lucide-lock"
        :label="`Travar em ${formatRate(rate.rate)}`"
        color="neutral"
        variant="subtle"
        size="sm"
        block
        @click="emit('update', { exchangeRate: rate.rate })"
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
  </section>
</template>
