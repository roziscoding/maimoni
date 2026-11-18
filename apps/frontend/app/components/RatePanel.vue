<script setup lang="ts">
import type { LiveRate, Month, MonthSummary, UpdateMonth, WiseQuote } from '@maimoni/shared'

const props = defineProps<{
  month: Month
  rate: LiveRate | null
  error: string | null
  summary: MonthSummary
  refreshing: boolean
  /** The month's stored Wise quote. */
  quote: WiseQuote | null
  /** Whether a new quote is being fetched. */
  quoting: boolean
}>()

const emit = defineEmits<{
  update: [patch: UpdateMonth]
  retry: []
  quote: []
}>()

const sources: Record<LiveRate['source'], string> = {
  'wise': 'Wise',
  'frankfurter': 'Frankfurter (BCE)',
  'open-er-api': 'Open Exchange Rates',
  'cache': 'último valor salvo',
}

const locked = computed(() => props.month.exchangeRate !== null)
const manualFee = computed(() => props.month.wiseFee !== null)

function setFee(value: number | null | undefined) {
  if (value !== null && value !== undefined && value !== props.month.wiseFee)
    emit('update', { wiseFee: value })
}
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

    <div class="space-y-2 p-4">
      <div class="flex items-center justify-between gap-2">
        <label :for="manualFee ? 'wise-fee' : undefined" class="text-sm font-medium text-muted">Taxa da projeção</label>
        <UFieldGroup size="xs" aria-label="Origem da taxa Wise">
          <UButton
            label="Wise"
            color="neutral"
            :variant="manualFee ? 'outline' : 'solid'"
            :aria-pressed="!manualFee"
            @click="manualFee && emit('update', { wiseFee: null })"
          />
          <UButton
            label="Manual"
            color="neutral"
            :variant="manualFee ? 'solid' : 'outline'"
            :aria-pressed="manualFee"
            @click="!manualFee && emit('update', { wiseFee: Math.round(summary.transfer.wiseFee * 1e5) / 1e5 })"
          />
        </UFieldGroup>
      </div>

      <UInputNumber
        v-if="manualFee"
        id="wise-fee"
        :model-value="month.wiseFee"
        :min="0"
        :max="0.99"
        :step="0.001"
        locale="pt-BR"
        :format-options="{ style: 'percent', minimumFractionDigits: 1, maximumFractionDigits: 2 }"
        class="w-full"
        :ui="{ base: 'money' }"
        @update:model-value="setFee"
      />
      <p v-else class="money text-xl font-semibold text-highlighted">
        {{ formatMoney(summary.transfer.projected.feeBrl, 'BRL') }}
        <span class="text-sm font-normal text-muted">({{ formatPercent(summary.transfer.wiseFee) }})</span>
      </p>

      <p v-if="summary.transfer.feeSource === 'fallback'" class="text-xs text-warning">
        Sem cotação da Wise para este mês; usando a taxa de reserva de {{ formatPercent(summary.transfer.wiseFee) }} das configurações.
      </p>
      <p v-else-if="summary.transfer.feeSource === 'wise' && quote" class="text-xs text-muted">
        Cotação da Wise de {{ formatDateTime(quote.fetchedAt) }}, para <span class="money">{{ formatMoney(quote.sendAmount, 'BRL') }}</span>: parte fixa + percentual.
        <template v-if="quote.sendAmount !== summary.transfer.projected.sentBrl">
          Aplicada em proporção aos <span class="money">{{ formatMoney(summary.transfer.projected.sentBrl, 'BRL') }}</span> restantes.
        </template>
      </p>
      <!-- The quote never updates by itself: the app asks Wise only when a month is created and here. -->
      <UButton
        v-if="!manualFee && summary.transfer.projected.sentBrl > 0"
        :label="quote ? 'Atualizar cotação' : 'Buscar cotação da Wise'"
        icon="i-lucide-refresh-cw"
        color="neutral"
        variant="subtle"
        size="sm"
        :loading="quoting"
        @click="emit('quote')"
      />
      <p v-else class="text-xs text-muted">
        Desconta <span class="money">{{ formatMoney(summary.transfer.projected.feeBrl, 'BRL') }}</span> dos reais que ainda serão convertidos.
      </p>
    </div>
  </section>
</template>
