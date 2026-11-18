<script setup lang="ts">
import type { Currency, EntryKind, LiveRate, MonthItem, TemplateDetail, TemplateItem, UpdateTemplateItem } from '@maimoni/shared'
import type { NewItem } from '~/components/AddItemForm.vue'
import { summarizeMonth } from '@maimoni/shared'

useHead({ title: 'Template · maimoni' })

const toast = useToast()
const { data, error, refresh } = await useFetch<TemplateDetail>('/api/template', { key: 'template' })
const { data: rate } = await useFetch<LiveRate>('/api/rates/live', { key: 'live-rate' })

const items = computed(() => data.value?.items.toSorted((a, b) => a.position - b.position) ?? [])

const sections: { currency: Currency, title: string }[] = [
  { currency: 'BRL', title: 'Reais' },
  { currency: 'EUR', title: 'Euros' },
]
const kinds: { kind: EntryKind, title: string }[] = [
  { kind: 'income', title: 'Entradas' },
  { kind: 'expense', title: 'Saídas' },
]
const group = (currency: Currency, kind: EntryKind) => items.value.filter(item => item.currency === currency && item.kind === kind)

// What a month created today from this template would look like, using next month's calendar.
const preview = computed(() => {
  if (!data.value)
    return null
  const now = new Date()
  const next = new Date(now.getFullYear(), now.getMonth() + 1, 1)
  const monthItems: MonthItem[] = items.value.map(item => ({
    ...item,
    monthId: '',
    templateItemId: item.id,
    paid: false,
    needsReview: item.variable,
  }))
  return summarizeMonth(
    { year: next.getFullYear(), month: next.getMonth() + 1, wiseFee: null, exchangeRate: null, activeDay: null },
    monthItems,
    // A real month gets Wise's quote when it is created; the preview doesn't ask Wise and uses the fallback fee.
    { rate: rate.value?.rate ?? null, fallbackFee: data.value.settings.wiseFee },
    now,
  )
})

function setItems(update: (items: TemplateItem[]) => TemplateItem[]) {
  if (data.value)
    data.value = { ...data.value, items: update(data.value.items) }
}

async function persist<T>(request: () => Promise<T>): Promise<T | undefined> {
  try {
    return await request()
  }
  catch (err) {
    toast.add({ title: 'Não foi possível salvar', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
    await refresh()
  }
}

async function updateItem(id: string, patch: UpdateTemplateItem) {
  setItems(list => list.map(item => item.id === id ? { ...item, ...patch } as TemplateItem : item))
  const saved = await persist(() => $fetch<TemplateItem>(`/api/template/items/${id}`, { method: 'PATCH', body: patch }))
  if (saved)
    setItems(list => list.map(item => item.id === id ? saved : item))
}

async function addItem(body: NewItem) {
  const created = await persist(() => $fetch<TemplateItem>('/api/template/items', { method: 'POST', body }))
  if (created)
    setItems(list => [...list, created])
}

async function removeItem(id: string) {
  setItems(list => list.filter(item => item.id !== id))
  await persist(() => $fetch(`/api/template/items/${id}`, { method: 'DELETE' }))
}

/** Swaps an item with its neighbour inside the same currency/kind group, then saves the full order. */
async function moveItem(item: TemplateItem, offset: -1 | 1) {
  const siblings = group(item.currency, item.kind)
  const neighbour = siblings[siblings.indexOf(item) + offset]
  if (!neighbour)
    return
  const ids = items.value.map(entry => entry.id === item.id ? neighbour.id : entry.id === neighbour.id ? item.id : entry.id)
  setItems(list => list.map(entry => ({ ...entry, position: ids.indexOf(entry.id) })))
  const saved = await persist(() => $fetch<TemplateItem[]>('/api/template/items/order', { method: 'PUT', body: { ids } }))
  if (saved)
    setItems(() => saved)
}
</script>

<template>
  <UDashboardPanel id="template">
    <template #header>
      <UDashboardNavbar title="Template" />
    </template>

    <template #body>
      <div v-if="data" class="mx-auto w-full max-w-6xl space-y-8 pb-10">
        <div class="max-w-2xl space-y-2">
          <h1 class="text-2xl font-semibold tracking-tight text-highlighted">
            O ponto de partida de todo mês
          </h1>
          <p class="text-sm text-muted">
            Cada mês novo começa com estes itens. Os fixos entram com o valor daqui; os marcados como
            <span class="font-medium text-default">varia</span> mudam todo mês (fatura do cartão, energia) e chegam
            pedindo confirmação, com o valor daqui como estimativa ou em branco.
          </p>
        </div>

        <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]">
          <div class="space-y-6">
            <section
              v-for="section in sections"
              :key="section.currency"
              :aria-labelledby="`template-${section.currency}`"
              class="rounded-xl border border-default"
            >
              <h2 :id="`template-${section.currency}`" class="flex items-baseline gap-2 border-b border-default px-4 py-3 text-base font-semibold text-highlighted">
                {{ section.title }}
                <span class="money text-xs font-normal text-muted">{{ section.currency }}</span>
              </h2>
              <div class="space-y-3 px-2 py-2 sm:px-3">
                <div v-for="entry in kinds" :key="entry.kind">
                  <h3 class="px-3 pb-1 pt-1 text-xs font-medium text-muted">
                    {{ entry.title }}
                  </h3>
                  <ul v-if="group(section.currency, entry.kind).length">
                    <TemplateRow
                      v-for="(item, index) in group(section.currency, entry.kind)"
                      :key="item.id"
                      :item="item"
                      :first="index === 0"
                      :last="index === group(section.currency, entry.kind).length - 1"
                      @update="updateItem(item.id, $event)"
                      @move="moveItem(item, $event)"
                      @remove="removeItem(item.id)"
                    />
                  </ul>
                  <p v-else class="px-3 pb-1 text-sm text-dimmed">
                    Nada aqui.
                  </p>
                </div>
                <AddItemForm :currency="section.currency" class="px-1" @add="addItem" />
              </div>
            </section>
          </div>

          <aside v-if="preview" class="space-y-4 lg:sticky lg:top-0" aria-labelledby="preview-title">
            <div>
              <h2 id="preview-title" class="text-base font-semibold text-highlighted">
                Prévia de um mês novo
              </h2>
              <p class="text-sm text-muted">
                Com a cotação de agora ({{ formatRate(rate?.rate) }}) e a taxa de reserva de {{ formatPercent(data.settings.wiseFee) }}.
                Itens variáveis em branco contam como zero.
              </p>
            </div>
            <FlowStrip :summary="preview" compact />
            <p class="flex items-baseline justify-between rounded-xl border border-default px-4 py-3">
              <span class="text-sm text-muted">Por dia, em {{ preview.allowance.days }} dias</span>
              <span class="money text-xl font-semibold text-highlighted">{{ formatMoney(preview.allowance.eur, 'EUR') }}</span>
            </p>
          </aside>
        </div>
      </div>

      <UEmpty
        v-else-if="error"
        icon="i-lucide-cloud-off"
        title="Não foi possível carregar o template"
        :description="errorMessage(error)"
        variant="naked"
        class="my-auto"
        :actions="[{ label: 'Tentar de novo', icon: 'i-lucide-refresh-cw', color: 'neutral', variant: 'subtle', onClick: () => refresh() }]"
      />
    </template>
  </UDashboardPanel>
</template>
