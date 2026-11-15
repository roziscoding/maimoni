<script setup lang="ts">
import type { Currency, CurrencyTotals, MonthItem, UpdateMonthItem } from '@maimoni/shared'
import type { NewItem } from './AddItemForm.vue'

const props = defineProps<{
  currency: Currency
  items: MonthItem[]
  totals: CurrencyTotals
}>()

const emit = defineEmits<{
  update: [id: string, patch: UpdateMonthItem]
  remove: [id: string]
  promote: [id: string]
  add: [item: NewItem]
}>()

const title = computed(() => props.currency === 'BRL' ? 'Reais' : 'Euros')
const incomes = computed(() => props.items.filter(item => item.kind === 'income'))
const expenses = computed(() => props.items.filter(item => item.kind === 'expense'))
// Sum of the listed incomes only: for EUR, `totals.income` also includes the Wise transfer.
const incomeTotal = computed(() => incomes.value.reduce((sum, item) => sum + (item.amount ?? 0), 0))
const paidShare = computed(() => props.totals.expenses > 0 ? Math.min(100, Math.round((props.totals.paid / props.totals.expenses) * 100)) : 0)
</script>

<template>
  <section :aria-labelledby="`section-${currency}`" class="rounded-xl border border-default bg-default">
    <header class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b border-default px-4 py-3">
      <h2 :id="`section-${currency}`" class="flex items-baseline gap-2 text-base font-semibold text-highlighted">
        {{ title }}
        <span class="money text-xs font-normal text-muted">{{ currency }}</span>
      </h2>
      <UBadge
        v-if="totals.unresolved"
        color="warning"
        variant="subtle"
        size="sm"
        icon="i-lucide-circle-dot"
        :label="totals.unresolved === 1 ? '1 valor a confirmar' : `${totals.unresolved} valores a confirmar`"
      />
    </header>

    <div class="px-2 py-2 sm:px-3">
      <template v-if="incomes.length">
        <h3 class="flex items-baseline justify-between px-3 pb-1 pt-1 text-xs font-medium text-muted">
          Entradas
          <span class="money text-toned">{{ formatMoney(incomeTotal, currency) }}</span>
        </h3>
        <ul class="pb-2">
          <ItemRow
            v-for="item in incomes"
            :key="item.id"
            :item="item"
            @update="emit('update', item.id, $event)"
            @remove="emit('remove', item.id)"
            @promote="emit('promote', item.id)"
          />
        </ul>
        <h3 class="px-3 pb-1 pt-2 text-xs font-medium text-muted">
          Saídas
        </h3>
      </template>

      <ul v-if="expenses.length">
        <ItemRow
          v-for="item in expenses"
          :key="item.id"
          :item="item"
          @update="emit('update', item.id, $event)"
          @remove="emit('remove', item.id)"
          @promote="emit('promote', item.id)"
        />
      </ul>
      <p v-else class="px-3 py-4 text-sm text-muted">
        Nenhuma saída em {{ title.toLowerCase() }} ainda.
      </p>

      <AddItemForm :currency="currency" class="px-1" @add="emit('add', $event)" />
    </div>

    <footer class="space-y-2 border-t border-default px-4 py-3">
      <div class="flex items-baseline justify-between gap-4">
        <span class="text-sm text-muted">Saída total</span>
        <span class="money text-base font-semibold text-highlighted">{{ formatMoney(totals.expenses, currency) }}</span>
      </div>
      <UProgress
        v-if="totals.expenses > 0"
        :model-value="paidShare"
        size="sm"
        color="neutral"
        :aria-label="`${paidShare}% das saídas pagas`"
      />
      <dl class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <dt class="text-muted">
            Pago
          </dt>
          <dd class="money text-default">
            {{ formatMoney(totals.paid, currency) }}
          </dd>
        </div>
        <div class="text-right">
          <dt class="text-muted">
            Falta pagar
          </dt>
          <dd class="money text-default">
            {{ formatMoney(totals.pending, currency) }}
          </dd>
        </div>
      </dl>
    </footer>
  </section>
</template>
