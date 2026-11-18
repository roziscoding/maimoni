<script setup lang="ts">
import type { MonthListEntry } from '@maimoni/shared'
import type { DropdownMenuItem } from '@nuxt/ui'
import { monthKeySchema, monthPhase } from '@maimoni/shared'

definePageMeta({ key: route => route.fullPath })

const route = useRoute()
const params = monthKeySchema.safeParse(route.params)
if (!params.success)
  throw createError({ statusCode: 404, statusMessage: 'Mês inválido' })
const { year, month } = params.data

const toast = useToast()
const { data, error, summary, refreshingRate, refreshRate, updateItem, addItem, removeItem, promoteItem, updateMonth, removeMonth, addConversion, updateConversion, removeConversion } = await useMonth(year, month)
const { data: months } = useNuxtData<MonthListEntry[]>('months')

const title = monthLabel(year, month)
useHead({ title: `${title} · maimoni` })

const phase = monthPhase(year, month)
const phaseLabel = { past: 'encerrado', current: 'mês atual', future: 'futuro' }[phase]
const hasPrevious = computed(() => months.value?.some(entry => entry.year * 12 + entry.month < year * 12 + month) ?? false)

const items = computed(() => data.value?.items.toSorted((a, b) => a.position - b.position) ?? [])
const brlItems = computed(() => items.value.filter(item => item.currency === 'BRL'))
const eurItems = computed(() => items.value.filter(item => item.currency === 'EUR'))

const note = ref(data.value?.month.note ?? '')
watch(() => data.value?.month.note, (value) => {
  note.value = value ?? ''
})
function saveNote() {
  const value = note.value.trim() || null
  if (value !== (data.value?.month.note ?? null))
    updateMonth({ note: value })
}

const confirmingDelete = ref(false)
const deleting = ref(false)
async function confirmDelete() {
  deleting.value = true
  try {
    await removeMonth()
    confirmingDelete.value = false
    toast.add({ title: `${title} excluído`, color: 'neutral', icon: 'i-lucide-trash-2' })
    await navigateTo('/')
  }
  catch (err) {
    toast.add({ title: 'Não foi possível excluir o mês', description: errorMessage(err), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    deleting.value = false
  }
}

const menu: DropdownMenuItem[] = [
  { label: 'Excluir mês', icon: 'i-lucide-trash-2', color: 'error', onSelect: () => (confirmingDelete.value = true) },
]
</script>

<template>
  <UDashboardPanel id="month">
    <template #header>
      <UDashboardNavbar :title="title">
        <template #trailing>
          <UBadge v-if="data" :label="phaseLabel" color="neutral" variant="subtle" size="sm" />
        </template>
        <template v-if="data" #right>
          <UDropdownMenu :items="menu" :content="{ align: 'end' }">
            <UButton icon="i-lucide-ellipsis-vertical" color="neutral" variant="ghost" aria-label="Ações do mês" />
          </UDropdownMenu>
        </template>
      </UDashboardNavbar>
    </template>

    <template #body>
      <div v-if="data && summary" class="mx-auto w-full max-w-6xl space-y-8 pb-10">
        <AllowanceHero :year="year" :month="month" :summary="summary" />

        <FlowStrip :summary="summary" />

        <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_19rem]">
          <div class="space-y-6">
            <ConversionSection
              :year="year"
              :month="month"
              :conversions="data.conversions"
              :rate="summary.transfer.rate"
              :create="addConversion"
              :update="updateConversion"
              :remove="removeConversion"
            />

            <ItemSection
              v-for="section in [{ currency: 'BRL' as const, items: brlItems }, { currency: 'EUR' as const, items: eurItems }]"
              :key="section.currency"
              :currency="section.currency"
              :items="section.items"
              :totals="section.currency === 'BRL' ? summary.brl : summary.eur"
              @update="updateItem"
              @remove="removeItem"
              @promote="promoteItem"
              @add="addItem"
            />
          </div>

          <aside class="space-y-6 lg:sticky lg:top-0">
            <RatePanel
              :month="data.month"
              :rate="data.rate"
              :error="data.rateError"
              :summary="summary"
              :refreshing="refreshingRate"
              @update="updateMonth"
              @retry="refreshRate"
            />

            <div class="space-y-1.5">
              <label for="month-note" class="text-sm font-medium text-muted">Anotações</label>
              <UTextarea
                id="month-note"
                v-model="note"
                placeholder="Algo para lembrar deste mês"
                :rows="3"
                autoresize
                :maxrows="12"
                class="w-full"
                @blur="saveNote"
              />
            </div>
          </aside>
        </div>
      </div>

      <MonthCreate
        v-else-if="error?.statusCode === 404"
        :year="year"
        :month="month"
        :has-previous="hasPrevious"
        class="my-auto"
      />

      <UEmpty
        v-else-if="error"
        icon="i-lucide-cloud-off"
        title="Não foi possível carregar o mês"
        :description="errorMessage(error)"
        variant="naked"
        class="my-auto"
        :actions="[{ label: 'Tentar de novo', icon: 'i-lucide-refresh-cw', color: 'neutral', variant: 'subtle', onClick: () => refreshNuxtData(`month-${year}-${month}`) }]"
      />

      <UModal
        v-model:open="confirmingDelete"
        :title="`Excluir ${title}?`"
        description="Todos os itens, valores e anotações deste mês serão apagados. O template não muda."
        :ui="{ footer: 'justify-end' }"
      >
        <template #footer="{ close }">
          <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
          <UButton label="Excluir mês" color="error" icon="i-lucide-trash-2" :loading="deleting" @click="confirmDelete" />
        </template>
      </UModal>
    </template>
  </UDashboardPanel>
</template>
