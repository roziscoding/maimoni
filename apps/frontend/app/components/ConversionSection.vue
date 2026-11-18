<script setup lang="ts">
import type { Conversion, CreateConversion } from '@maimoni/shared'
import type { FormSubmitEvent } from '@nuxt/ui'
import type * as z from 'zod'
import { conversionFee, createConversionSchema, daysInMonth } from '@maimoni/shared'

type ConversionForm = z.output<typeof createConversionSchema>

const props = defineProps<{
  year: number
  month: number
  conversions: Conversion[]
  /** EUR→BRL rate the month is using, which the fee of a new conversion is worked out from. */
  rate: number | null
  create: (input: CreateConversion) => Promise<Conversion | undefined>
  update: (id: string, input: CreateConversion) => Promise<Conversion | undefined>
  remove: (id: string) => Promise<void>
}>()

const open = ref(false)
const editing = ref<Conversion | null>(null)
const deleting = ref<Conversion | null>(null)
const saving = ref(false)
const deletingNow = ref(false)
const state = reactive<ConversionForm>({ day: 1, sentBrl: 0, receivedEur: 0, note: null })

const sorted = computed(() => props.conversions.toSorted((a, b) => b.day - a.day || b.createdAt.localeCompare(a.createdAt)))
const maxDay = computed(() => daysInMonth(props.year, props.month))

// The fee isn't typed in. The server works it out from the rate when the amounts are saved; this
// shows what it will be. A conversion being edited keeps its fee while its amounts stay the same.
const amountsChanged = computed(() => !editing.value || editing.value.sentBrl !== state.sentBrl || editing.value.receivedEur !== state.receivedEur)
const fee = computed(() => {
  if (!amountsChanged.value)
    return editing.value!.feeBrl
  return state.sentBrl > 0 && state.receivedEur > 0 && props.rate ? conversionFee(state, props.rate) : null
})

function defaultDay() {
  const now = new Date()
  return now.getFullYear() === props.year && now.getMonth() + 1 === props.month ? now.getDate() : 1
}

function show(conversion?: Conversion) {
  editing.value = conversion ?? null
  Object.assign(state, conversion
    ? { day: conversion.day, sentBrl: conversion.sentBrl, receivedEur: conversion.receivedEur, note: conversion.note }
    : { day: defaultDay(), sentBrl: 0, receivedEur: 0, note: null })
  open.value = true
}

async function submit(event: FormSubmitEvent<ConversionForm>) {
  saving.value = true
  const saved = editing.value
    ? await props.update(editing.value.id, event.data)
    : await props.create(event.data)
  saving.value = false
  if (saved)
    open.value = false
}

async function confirmDelete() {
  if (!deleting.value)
    return
  deletingNow.value = true
  await props.remove(deleting.value.id)
  deletingNow.value = false
  deleting.value = null
}
</script>

<template>
  <section aria-labelledby="conversions-title" class="rounded-xl border border-default">
    <div class="flex items-center justify-between gap-3 border-b border-default px-4 py-3">
      <div>
        <h2 id="conversions-title" class="text-base font-semibold text-highlighted">
          Conversões
        </h2>
        <p class="text-xs text-muted">
          Reais enviados e euros que já chegaram.
        </p>
      </div>
      <UButton label="Lançar conversão" icon="i-lucide-arrow-right-left" color="neutral" variant="subtle" @click="show()" />
    </div>

    <ul v-if="sorted.length" class="divide-y divide-default px-2 py-1 sm:px-3">
      <li v-for="conversion in sorted" :key="conversion.id" class="flex items-center gap-3 px-2 py-3">
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-highlighted">
            {{ dayLabel(year, month, conversion.day) }}
          </p>
          <p v-if="conversion.note" class="truncate text-xs text-muted">
            {{ conversion.note }}
          </p>
        </div>
        <div class="shrink-0 text-right">
          <p class="money text-sm text-toned">
            {{ formatMoney(conversion.sentBrl, 'BRL') }}
            <span class="text-muted">→</span>
            <span class="font-medium text-highlighted">{{ formatMoney(conversion.receivedEur, 'EUR') }}</span>
          </p>
          <p class="money text-xs text-muted">
            {{ formatMoney(conversion.feeBrl, 'BRL') }} de taxa
          </p>
        </div>
        <UButton icon="i-lucide-pencil" color="neutral" variant="ghost" size="sm" aria-label="Editar conversão" @click="show(conversion)" />
        <UButton icon="i-lucide-trash-2" color="error" variant="ghost" size="sm" aria-label="Excluir conversão" @click="deleting = conversion" />
      </li>
    </ul>
    <p v-else class="px-4 py-5 text-sm text-muted">
      Nenhuma conversão lançada neste mês.
    </p>
  </section>

  <UModal
    v-model:open="open"
    :title="editing ? 'Editar conversão' : 'Lançar conversão'"
    description="Informe quanto saiu em reais e quanto chegou em euros. A taxa é o que sobra da conta com o câmbio."
    :ui="{ footer: 'justify-end' }"
  >
    <template #body>
      <UForm id="conversion-form" :schema="createConversionSchema" :state="state" class="space-y-5" @submit="submit">
        <UFormField name="day" label="Dia">
          <UInputNumber v-model="state.day" :min="1" :max="maxDay" :format-options="{ useGrouping: false }" class="w-full" />
        </UFormField>

        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField name="sentBrl" label="BRL enviado">
            <UInputNumber
              v-model="state.sentBrl"
              :min="0"
              :step="0.01"
              locale="pt-BR"
              :format-options="{ style: 'currency', currency: 'BRL', currencyDisplay: 'narrowSymbol' }"
              class="w-full"
            />
          </UFormField>
          <UFormField name="receivedEur" label="EUR recebido">
            <UInputNumber
              v-model="state.receivedEur"
              :min="0"
              :step="0.01"
              locale="pt-BR"
              :format-options="{ style: 'currency', currency: 'EUR', currencyDisplay: 'narrowSymbol' }"
              class="w-full"
            />
          </UFormField>
        </div>

        <p v-if="fee !== null" class="text-sm text-muted">
          Taxa: <span class="money font-medium text-highlighted">{{ formatMoney(fee, 'BRL') }}</span>
          <template v-if="amountsChanged">
            , com o euro a <span class="money">{{ formatRate(rate) }}</span>.
          </template>
          <template v-else>
            , calculada quando a conversão foi lançada.
          </template>
        </p>
        <p v-else-if="!rate" class="text-sm text-warning">
          Sem cotação do euro agora, a taxa desta conversão fica em zero.
        </p>

        <UFormField name="note" label="Anotação" hint="Opcional">
          <UInput v-model="state.note" placeholder="Ex.: dinheiro para aluguel" class="w-full" />
        </UFormField>
      </UForm>
    </template>

    <template #footer="{ close }">
      <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
      <UButton type="submit" form="conversion-form" :label="editing ? 'Salvar' : 'Lançar'" icon="i-lucide-check" :loading="saving" />
    </template>
  </UModal>

  <UModal
    :open="deleting !== null"
    title="Excluir conversão?"
    description="O saldo e a projeção do mês serão recalculados sem ela."
    :ui="{ footer: 'justify-end' }"
    @update:open="!$event && (deleting = null)"
  >
    <template #footer>
      <UButton label="Cancelar" color="neutral" variant="outline" @click="deleting = null" />
      <UButton label="Excluir" color="error" icon="i-lucide-trash-2" :loading="deletingNow" @click="confirmDelete" />
    </template>
  </UModal>
</template>
