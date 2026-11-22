<script setup lang="ts">
import type { Currency, ReplaceUserCurrencies, UserCurrency } from '@maimoni/shared'
import { currencies as knownCurrencies } from '@maimoni/shared'

const toast = useToast()
const { data: saved, error } = await useFetch<UserCurrency[]>('/api/settings/currencies', { key: 'currencies' })

/** The list being edited. Nothing reaches the server until it is saved, all at once. */
const draft = ref<ReplaceUserCurrencies['currencies']>([])
const main = ref<Currency | null>(null)

function reset() {
  draft.value = (saved.value ?? []).map(({ currency, enabled }) => ({ currency, enabled }))
  main.value = saved.value?.find(entry => entry.main)?.currency ?? null
}
watch(saved, reset, { immediate: true })

/** Every currency the app knows, with the user's entry for the ones in their list. */
const rows = computed(() => knownCurrencies.map(currency => ({
  currency,
  entry: draft.value.find(entry => entry.currency === currency),
  main: main.value === currency,
})))

/** Order doesn't count as a change: the server sorts the list. */
function snapshot(entries: ReplaceUserCurrencies['currencies'], mainCurrency: Currency | null) {
  return JSON.stringify([entries.map(({ currency, enabled }) => [currency, enabled]).sort(), mainCurrency])
}
const dirty = computed(() => snapshot(draft.value, main.value) !== snapshot(saved.value ?? [], saved.value?.find(entry => entry.main)?.currency ?? null))

function add(currency: Currency) {
  draft.value.push({ currency, enabled: true })
  // The first one is the main one, as on the server.
  main.value ??= currency
}

function remove(currency: Currency) {
  draft.value = draft.value.filter(entry => entry.currency !== currency)
}

const saving = ref(false)

async function save() {
  if (!main.value)
    return
  saving.value = true
  try {
    saved.value = await $fetch<UserCurrency[]>('/api/settings/currencies', { method: 'PUT', body: { currencies: draft.value, main: main.value } satisfies ReplaceUserCurrencies })
    toast.add({ title: 'Moedas salvas', color: 'success', icon: 'i-lucide-check' })
  }
  catch (err) {
    // The server refuses to remove a currency that items or spends are in.
    const inUse = (err as { statusCode?: number } | null)?.statusCode === 409
    toast.add({
      title: 'Não foi possível salvar as moedas',
      description: inUse ? 'Uma moeda removida ainda tem itens ou gastos. Desative-a em vez de remover.' : errorMessage(err),
      color: 'error',
      icon: 'i-lucide-circle-alert',
    })
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <section aria-labelledby="currencies-title" class="space-y-3">
    <div class="space-y-1">
      <h2 id="currencies-title" class="text-sm font-semibold text-highlighted">
        Moedas
      </h2>
      <p class="text-sm text-muted">
        As moedas que você usa. Uma moeda desativada mantém o histórico e deixa de ser oferecida.
      </p>
    </div>

    <template v-if="saved">
      <ul class="divide-y divide-default rounded-xl border border-default">
        <li v-for="row in rows" :key="row.currency" class="flex flex-wrap items-center gap-x-3 gap-y-2 p-3">
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium text-highlighted">
              {{ currencyName(row.currency) }}
              <UBadge v-if="row.main" label="Principal" color="neutral" variant="subtle" size="sm" class="ml-1" />
            </p>
            <p class="money text-sm text-muted">
              {{ row.currency }}
            </p>
          </div>

          <template v-if="row.entry">
            <UButton
              v-if="!row.main"
              label="Tornar principal"
              color="neutral"
              variant="subtle"
              size="sm"
              :disabled="!row.entry.enabled || saving"
              @click="main = row.currency"
            />
            <!-- The main currency is always active: another one has to take its place first. -->
            <USwitch
              v-model="row.entry.enabled"
              size="sm"
              label="ativa"
              :aria-label="`${currencyName(row.currency)} ativa`"
              :disabled="row.main || saving"
              :ui="{ label: 'text-xs text-muted font-normal' }"
            />
            <UButton
              icon="i-lucide-trash-2"
              color="neutral"
              variant="ghost"
              size="sm"
              :aria-label="`Remover ${currencyName(row.currency)}`"
              :disabled="row.main || saving"
              @click="remove(row.currency)"
            />
          </template>
          <UButton
            v-else
            label="Adicionar"
            icon="i-lucide-plus"
            color="neutral"
            variant="outline"
            size="sm"
            :disabled="saving"
            @click="add(row.currency)"
          />
        </li>
      </ul>

      <div v-if="dirty" class="flex justify-end gap-2">
        <UButton label="Descartar" color="neutral" variant="outline" :disabled="saving" @click="reset" />
        <UButton label="Salvar moedas" icon="i-lucide-check" :loading="saving" :disabled="!main" @click="save" />
      </div>
    </template>
    <p v-else-if="error" class="text-sm text-error">
      Não foi possível carregar as moedas: {{ errorMessage(error) }}
    </p>
  </section>
</template>
