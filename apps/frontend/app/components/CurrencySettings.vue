<script setup lang="ts">
import type { AddUserCurrency, Currency, UpdateUserCurrency, UserCurrency } from '@maimoni/shared'
import { currencies as knownCurrencies } from '@maimoni/shared'

const toast = useToast()
// Nuxt doesn't fetch again for a key another screen already loaded, and that list goes out of date
// here: whether a currency is in use changes as items and spends are added and removed elsewhere.
const loadedElsewhere = useNuxtData('currencies').data.value != null
const { data: saved, error, refresh } = await useFetch<UserCurrency[]>('/api/settings/currencies', { key: 'currencies' })
if (loadedElsewhere)
  await refresh()

/** The user's currencies: the main one first, then the rest in the app's order. */
const rows = computed(() => {
  const entries = saved.value ?? []
  const position = (currency: Currency) => knownCurrencies.indexOf(currency)
  return entries.toSorted((a, b) => Number(b.main) - Number(a.main) || position(a.currency) - position(b.currency)).map((entry) => {
    const name = currencyName(entry.currency)
    return {
      currency: entry.currency,
      name,
      symbol: currencySymbol(entry.currency),
      entry,
      removeBlocked: entry.main || entry.inUse,
      // What the icon does, or why it is blocked; shown on hover and focus.
      removeHint: entry.main
        ? 'A moeda principal não pode ser removida.'
        : entry.inUse
          ? `${name} possui itens ou gastos registrados.`
          : `Remover ${name}`,
      // Why the switch is blocked.
      enabledHint: entry.main ? 'A moeda principal não pode ser desativada.' : undefined,
    }
  })
})

/** The currencies still to add, for the picker: found by name or by code. */
const available = computed(() => knownCurrencies
  .filter(currency => !saved.value?.some(entry => entry.currency === currency))
  .map(currency => ({ label: currencyName(currency), value: currency, code: currency }))
  .toSorted((a, b) => a.label.localeCompare(b.label, 'pt-BR')))
/** The picker only chooses what to add; it goes back to empty once it did. */
const picked = ref<Currency>()
async function pick(currency: Currency | undefined) {
  if (!currency)
    return
  await add(currency)
  picked.value = undefined
}

/** The currency a request is running for. Every action applies at once, one at a time. */
const busy = ref<Currency | null>(null)

/** Runs one change and takes the list it answers with, or loads the list again when it answers with something else. */
async function change(currency: Currency, failure: string, request: () => Promise<UserCurrency[] | unknown>) {
  busy.value = currency
  try {
    const result = await request()
    if (Array.isArray(result))
      saved.value = result
    else
      await refresh()
    return true
  }
  catch (err) {
    toast.add({ title: failure, description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
    // What the server refused may mean the list on screen is out of date.
    await refresh()
    return false
  }
  finally {
    busy.value = null
  }
}

const base = '/api/settings/currencies'

function add(currency: Currency) {
  return change(currency, 'Não foi possível adicionar a moeda', () => $fetch(base, { method: 'POST', body: { currency } satisfies AddUserCurrency }))
}

function update(currency: Currency, patch: UpdateUserCurrency, failure: string) {
  return change(currency, failure, () => $fetch<UserCurrency[]>(`${base}/${currency}`, { method: 'PATCH', body: patch }))
}

/** The currency the user asked to remove and hasn't confirmed yet. Kept while the dialog closes so its text doesn't change. */
const removing = ref<Currency | null>(null)
const confirmingRemove = ref(false)

function askToRemove(currency: Currency) {
  removing.value = currency
  confirmingRemove.value = true
}

async function remove() {
  if (!removing.value)
    return
  await change(removing.value, 'Não foi possível remover a moeda', () => $fetch(`${base}/${removing.value}`, { method: 'DELETE' }))
  confirmingRemove.value = false
}
</script>

<template>
  <SettingsSection title="Moedas" description="Moedas usadas nos itens e gastos. Uma moeda desativada deixa de ser oferecida e mantém o histórico.">
    <ul v-if="saved" class="divide-y divide-default">
      <li v-for="row in rows" :key="row.currency" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3">
        <!-- The sign its amounts are written with. It dims with the name when the currency isn't offered. -->
        <div class="flex min-w-0 flex-1 items-center gap-3" :class="{ 'opacity-50': !row.entry.enabled }">
          <span class="money grid size-9 shrink-0 place-items-center rounded-lg bg-elevated text-sm font-medium text-highlighted" aria-hidden="true">
            {{ row.symbol }}
          </span>
          <div class="min-w-0">
            <p class="truncate text-sm font-medium text-highlighted">
              {{ row.name }}
            </p>
            <p class="money text-xs text-muted">
              {{ row.currency }}
            </p>
          </div>
        </div>

        <div class="flex items-center gap-1">
          <UBadge v-if="row.entry.main" label="Principal" icon="i-lucide-star" color="neutral" variant="subtle" class="mr-2" />
          <!-- A disabled currency can't be the main one, so it isn't offered the button. -->
          <UButton
            v-else-if="row.entry.enabled"
            label="Definir como principal"
            color="neutral"
            variant="ghost"
            size="sm"
            class="mr-2"
            :disabled="busy !== null"
            @click="update(row.currency, { main: true }, 'Não foi possível definir a moeda principal')"
          />

          <!-- Takes effect when flipped, as a switch says it does. A disabled control gets no hover or focus of its own, so the hint sits on a wrapper. -->
          <UTooltip :text="row.enabledHint">
            <span class="inline-flex rounded-md" :tabindex="row.entry.main ? 0 : undefined">
              <USwitch
                :model-value="row.entry.enabled"
                size="sm"
                label="Ativa"
                :aria-label="`${row.name} ativa`"
                :loading="busy === row.currency"
                :disabled="row.entry.main || busy !== null"
                class="px-2"
                :ui="{ label: 'text-xs text-muted font-normal' }"
                @update:model-value="update(row.currency, { enabled: $event }, $event ? 'Não foi possível ativar a moeda' : 'Não foi possível desativar a moeda')"
              />
            </span>
          </UTooltip>

          <UTooltip :text="row.removeHint">
            <span class="inline-flex rounded-md" :tabindex="row.removeBlocked ? 0 : undefined">
              <UButton
                icon="i-lucide-trash-2"
                color="error"
                variant="ghost"
                size="sm"
                :aria-label="row.removeHint"
                :disabled="row.removeBlocked || busy !== null"
                @click="askToRemove(row.currency)"
              />
            </span>
          </UTooltip>
        </div>
      </li>
      <li v-if="!rows.length" class="px-4 py-3 text-sm text-muted">
        Nenhuma moeda adicionada. A primeira será a principal.
      </li>
    </ul>
    <p v-else-if="error" class="px-4 py-3 text-sm text-error">
      Não foi possível carregar as moedas: {{ errorMessage(error) }}
    </p>

    <template v-if="saved && available.length" #footer>
      <USelectMenu
        v-model="picked"
        :items="available"
        value-key="value"
        :filter-fields="['label', 'code']"
        placeholder="Adicionar moeda"
        icon="i-lucide-plus"
        :search-input="{ placeholder: 'Buscar por nome ou código' }"
        :loading="busy !== null && !rows.some(row => row.currency === busy)"
        :disabled="busy !== null"
        aria-label="Adicionar moeda"
        class="w-full sm:w-72"
        @update:model-value="pick"
      >
        <template #item-trailing="{ item }">
          <span class="money text-xs text-muted">{{ item.code }}</span>
        </template>
      </USelectMenu>
    </template>

    <!-- Only exists once there is a currency to ask about, which then stays set for the dialog to close with its title. -->
    <UModal
      v-if="removing"
      v-model:open="confirmingRemove"
      :title="`Remover ${currencyName(removing)}?`"
      description="A moeda deixará de ser oferecida para novos itens e gastos. É possível adicioná-la novamente depois."
      :ui="{ footer: 'justify-end' }"
    >
      <template #footer="{ close }">
        <UButton label="Cancelar" color="neutral" variant="outline" :disabled="busy !== null" @click="close" />
        <UButton label="Remover moeda" color="error" icon="i-lucide-trash-2" :loading="busy !== null" @click="remove" />
      </template>
    </UModal>
  </SettingsSection>
</template>
