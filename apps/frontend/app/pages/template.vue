<script setup lang="ts">
import type { EntryKind } from '@maimoni/shared'

useHead({ title: 'Template · maimoni' })

const template = useTemplate()
const { data, error, refresh, currencies, sections, exchange, group, updateItem, addItem, removeItem, moveItem } = template
await template.ready

const kinds: { kind: EntryKind, title: string }[] = [
  { kind: 'income', title: 'Entradas' },
  { kind: 'expense', title: 'Saídas' },
]

// What a month created today from this template would look like, using next month's calendar.
const preview = computed(() => {
  const now = new Date()
  const next = new Date(now.getFullYear(), now.getMonth() + 1, 1)
  return template.summaryFor(next.getFullYear(), next.getMonth() + 1)
})
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

        <NoCurrenciesAlert v-if="currencies.none.value" />

        <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]">
          <div class="space-y-6">
            <section
              v-for="section in sections"
              :key="section.currency"
              :aria-labelledby="`template-${section.currency}`"
              class="rounded-xl border border-default"
            >
              <h2 :id="`template-${section.currency}`" class="flex items-baseline gap-2 border-b border-default px-4 py-3 text-base font-semibold text-highlighted" :class="{ 'sr-only': !exchange }">
                {{ exchange ? section.title : 'Itens do template' }}
                <span v-if="exchange" class="money text-xs font-normal text-muted">{{ section.currency }}</span>
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
                <AddItemForm v-if="section.offered" :currency="section.currency" class="px-1" @add="addItem" />
              </div>
            </section>
          </div>

          <aside v-if="preview" class="space-y-4 lg:sticky lg:top-0" aria-labelledby="preview-title">
            <div>
              <h2 id="preview-title" class="text-base font-semibold text-highlighted">
                Prévia de um mês novo
              </h2>
              <p class="text-sm text-muted">
                <template v-if="preview.conversions.length">
                  Com a cotação de agora ({{ preview.conversions.map(conversion => formatRate(conversion.rate, conversion.currency)).join(', ') }}).
                </template>
                Itens variáveis em branco contam como zero.
              </p>
            </div>
            <FlowStrip :summary="preview" :currencies="sections.map(section => section.currency)" compact />
            <p class="flex items-baseline justify-between rounded-xl border border-default px-4 py-3">
              <span class="text-sm text-muted">Por dia, em {{ preview.allowance.days }} dias</span>
              <span class="money text-xl font-semibold text-highlighted">{{ formatMoney(preview.allowance.amount, preview.main) }}</span>
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
