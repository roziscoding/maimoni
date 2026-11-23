<script setup lang="ts">
import type { Currency } from '@maimoni/shared'

const props = defineProps<{
  /** The currencies to choose from. */
  options: Currency[]
  /** Whether more than one can be chosen. Without it, choosing one replaces the other. */
  multiple?: boolean
  /** Currencies that come first, in this order. The rest follow by name. */
  pinned?: Currency[]
  /** What the choice is, for screen readers. */
  label: string
}>()

/** Where a currency sits among the pinned ones; the others all come after them. */
function rank(currency: Currency) {
  const index = props.pinned?.indexOf(currency) ?? -1
  return index === -1 ? Number.POSITIVE_INFINITY : index
}

/** The chosen currencies, in the order they were chosen. */
const selected = defineModel<Currency[]>({ required: true })

/** Lowercase and without accents, so `dolar` finds `Dólar`. */
const plain = (value: string) => value.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()

const query = ref('')
/** A short list is read at a glance; a long one needs a way to find a currency. */
const searchable = computed(() => props.options.length > 8)
const tiles = computed(() => {
  const wanted = plain(query.value.trim())
  return props.options
    .map(currency => ({ currency, name: currencyName(currency), symbol: currencySymbol(currency) }))
    .filter(tile => !wanted || plain(tile.name).includes(wanted) || tile.currency.toLowerCase().includes(wanted))
    .toSorted((a, b) => {
      const [first, second] = [rank(a.currency), rank(b.currency)]
      return first === second ? a.name.localeCompare(b.name, 'pt-BR') : first - second
    })
})

function toggle(currency: Currency) {
  if (!props.multiple)
    selected.value = [currency]
  else if (selected.value.includes(currency))
    selected.value = selected.value.filter(entry => entry !== currency)
  else
    selected.value = [...selected.value, currency]
}
</script>

<template>
  <div class="space-y-3">
    <UInput
      v-if="searchable"
      v-model="query"
      icon="i-lucide-search"
      placeholder="Buscar por nome ou código"
      aria-label="Buscar moeda"
      class="w-full"
    />
    <!-- The padding leaves room for the focus ring, which the scroll container would clip. -->
    <div :role="multiple ? 'group' : 'radiogroup'" :aria-label="label" class="grid max-h-72 grid-cols-1 gap-2 overflow-y-auto p-0.5 sm:grid-cols-2">
      <button
        v-for="tile in tiles"
        :key="tile.currency"
        type="button"
        :role="multiple ? 'checkbox' : 'radio'"
        :aria-checked="selected.includes(tile.currency)"
        class="flex items-center gap-3 rounded-lg border p-2.5 text-left transition-colors focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-primary"
        :class="selected.includes(tile.currency) ? 'border-primary bg-elevated' : 'border-default hover:bg-elevated/60'"
        @click="toggle(tile.currency)"
      >
        <span class="money grid h-9 min-w-9 shrink-0 place-items-center rounded-md bg-accented px-1.5 text-sm font-medium text-highlighted" aria-hidden="true">
          {{ tile.symbol }}
        </span>
        <span class="min-w-0 flex-1">
          <span class="block truncate text-sm font-medium text-highlighted">{{ tile.name }}</span>
          <span class="money block text-xs text-muted">{{ tile.currency }}</span>
        </span>
        <UIcon v-if="selected.includes(tile.currency)" name="i-lucide-check" class="size-4 shrink-0 text-primary" />
      </button>
    </div>
    <p v-if="!tiles.length" class="text-sm text-muted">
      Nenhuma moeda com esse nome.
    </p>
  </div>
</template>
