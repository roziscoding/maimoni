<script setup lang="ts">
import type { CurrenciesInUseError, Currency, ReplaceUserCurrencies, UserCurrency } from '@maimoni/shared'
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

/** The main currency first, then the rest of the user's list, then the currencies not in it. */
const order = computed(() => {
  const rank = (currency: Currency) => currency === main.value ? 0 : draft.value.some(entry => entry.currency === currency) ? 1 : 2
  // The sort is stable, so each group keeps the app's order.
  return knownCurrencies.toSorted((a, b) => rank(a) - rank(b))
})

/** Every currency the app knows, with the user's entry for the ones in their list. */
const rows = computed(() => order.value.map((currency) => {
  const name = currencyName(currency)
  const isMain = main.value === currency
  return {
    currency,
    name,
    symbol: currencySymbol(currency),
    entry: draft.value.find(entry => entry.currency === currency),
    main: isMain,
    // Why a control is blocked, shown on hover and focus.
    removeHint: isMain ? 'Para remover esta moeda, defina outra como principal.' : `Remover ${name}`,
    enabledHint: isMain ? 'Para desativar esta moeda, defina outra como principal.' : undefined,
  }
}))

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
/** Removed currencies the server refused to remove. While there are any, a dialog offers to disable them instead. */
const blocked = ref<Currency[]>([])

async function save() {
  if (!main.value)
    return
  saving.value = true
  try {
    saved.value = await $fetch<UserCurrency[]>('/api/settings/currencies', { method: 'PUT', body: { currencies: draft.value, main: main.value } satisfies ReplaceUserCurrencies })
    toast.add({ title: 'Moedas salvas', color: 'success', icon: 'i-lucide-check' })
  }
  catch (err) {
    // The server refuses to remove a currency that items or spends are in, and says which.
    const inUse = (err as { data?: Partial<CurrenciesInUseError> } | null)?.data?.inUse
    if (inUse?.length)
      blocked.value = inUse
    else
      toast.add({ title: 'Não foi possível salvar as moedas', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    saving.value = false
  }
}

const showingBlocked = computed({
  get: () => blocked.value.length > 0,
  set: (open) => {
    if (!open)
      blocked.value = []
  },
})

const names = new Intl.ListFormat('pt-BR', { type: 'conjunction' })
const blockedDialog = computed(() => {
  const list = names.format(blocked.value.map(currencyName))
  return blocked.value.length === 1
    ? {
        title: `Não é possível remover ${list}`,
        description: `${list} possui itens ou gastos registrados. Para que deixe de ser oferecida, desative a moeda em vez de removê-la.`,
      }
    : {
        title: `Não é possível remover ${list}`,
        description: `${list} possuem itens ou gastos registrados. Para que deixem de ser oferecidas, desative as moedas em vez de removê-las.`,
      }
})

/** Puts the refused currencies back in the list, disabled, and saves. */
async function disableBlocked() {
  draft.value = [...draft.value, ...blocked.value.map(currency => ({ currency, enabled: false }))]
  blocked.value = []
  await save()
}
</script>

<template>
  <SettingsSection title="Moedas" description="Moedas usadas nos itens e gastos. Uma moeda desativada deixa de ser exibida e mantém o histórico.">
    <ul v-if="saved" class="divide-y divide-default">
      <li v-for="row in rows" :key="row.currency" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3">
        <!-- The sign its amounts are written with. It dims with the name when the currency isn't offered. -->
        <div class="flex min-w-0 flex-1 items-center gap-3" :class="{ 'opacity-50': !row.entry?.enabled }">
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

        <div v-if="row.entry" class="flex items-center gap-1">
          <UBadge v-if="row.main" label="Principal" icon="i-lucide-star" color="neutral" variant="subtle" class="mr-2" />
          <!-- A disabled button gets no hover or focus of its own, so the hint sits on a wrapper. -->
          <UTooltip v-else :text="row.entry.enabled ? undefined : 'Ative esta moeda para defini-la como principal.'">
            <span class="mr-2 inline-flex rounded-md" :tabindex="row.entry.enabled ? undefined : 0">
              <UButton
                label="Definir como principal"
                color="neutral"
                variant="ghost"
                size="sm"
                :disabled="!row.entry.enabled || saving"
                @click="main = row.currency"
              />
            </span>
          </UTooltip>

          <UTooltip :text="row.enabledHint">
            <span class="inline-flex rounded-md" :tabindex="row.main ? 0 : undefined">
              <USwitch
                v-model="row.entry.enabled"
                size="sm"
                label="Ativa"
                :aria-label="`${row.name} ativa`"
                :disabled="row.main || saving"
                class="px-2"
                :ui="{ label: 'text-xs text-muted font-normal' }"
              />
            </span>
          </UTooltip>

          <UTooltip :text="row.removeHint">
            <span class="inline-flex rounded-md" :tabindex="row.main ? 0 : undefined">
              <UButton
                icon="i-lucide-trash-2"
                color="neutral"
                variant="ghost"
                size="sm"
                :aria-label="row.removeHint"
                :disabled="row.main || saving"
                @click="remove(row.currency)"
              />
            </span>
          </UTooltip>
        </div>
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
    <p v-else-if="error" class="px-4 py-3 text-sm text-error">
      Não foi possível carregar as moedas: {{ errorMessage(error) }}
    </p>

    <template v-if="dirty" #footer>
      <p class="mr-auto text-sm text-muted">
        Alterações não salvas
      </p>
      <UButton label="Descartar alterações" color="neutral" variant="outline" :disabled="saving" @click="reset" />
      <UButton label="Salvar moedas" icon="i-lucide-check" :loading="saving" :disabled="!main" @click="save" />
    </template>

    <UModal v-model:open="showingBlocked" :title="blockedDialog.title" :description="blockedDialog.description" :ui="{ footer: 'justify-end' }">
      <template #footer="{ close }">
        <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
        <UButton label="Desativar e salvar" icon="i-lucide-check" @click="disableBlocked" />
      </template>
    </UModal>
  </SettingsSection>
</template>
