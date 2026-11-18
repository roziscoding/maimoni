<script setup lang="ts">
import type { Conversion, CreateConversion, WiseQuote } from '@maimoni/shared'
import type { FormSubmitEvent } from '@nuxt/ui'
import type * as z from 'zod'
import { createConversionSchema, daysInMonth } from '@maimoni/shared'

type ConversionForm = z.output<typeof createConversionSchema>
type QuoteMode = 'EUR' | 'BRL'

const props = defineProps<{
  year: number
  month: number
  conversions: Conversion[]
  create: (input: CreateConversion) => Promise<Conversion | undefined>
  update: (id: string, input: CreateConversion) => Promise<Conversion | undefined>
  remove: (id: string) => Promise<void>
}>()

const open = ref(false)
const editing = ref<Conversion | null>(null)
const deleting = ref<Conversion | null>(null)
const mode = ref<QuoteMode>('EUR')
const saving = ref(false)
const deletingNow = ref(false)
const quoting = ref(false)
const quoteError = ref<string | null>(null)
const state = reactive<ConversionForm>({ day: 1, sentBrl: 0, feeBrl: 0, receivedEur: 0, note: null })
let quoteVersion = 0

const sorted = computed(() => props.conversions.toSorted((a, b) => b.day - a.day || b.createdAt.localeCompare(a.createdAt)))
const maxDay = computed(() => daysInMonth(props.year, props.month))

function defaultDay() {
  const now = new Date()
  return now.getFullYear() === props.year && now.getMonth() + 1 === props.month ? now.getDate() : 1
}

function reset(conversion?: Conversion) {
  editing.value = conversion ?? null
  mode.value = 'EUR'
  quoteError.value = null
  Object.assign(state, conversion
    ? { day: conversion.day, sentBrl: conversion.sentBrl, feeBrl: conversion.feeBrl, receivedEur: conversion.receivedEur, note: conversion.note }
    : { day: defaultDay(), sentBrl: 0, feeBrl: 0, receivedEur: 0, note: null })
}

function show(conversion?: Conversion) {
  reset(conversion)
  open.value = true
}

function quoteKey() {
  const amount = mode.value === 'EUR' ? state.receivedEur : state.sentBrl
  return amount > 0 ? `${mode.value}:${amount}` : ''
}

/** Fills the other amount and the fee from Wise. Only on request: the form never asks Wise by itself. */
async function requestQuote() {
  const key = quoteKey()
  if (!key)
    return
  quoteError.value = null
  quoting.value = true
  const version = ++quoteVersion
  try {
    const query = mode.value === 'EUR'
      ? { recipientGetsAmount: state.receivedEur }
      : { sendAmount: state.sentBrl }
    const quote = await $fetch<WiseQuote>('/api/wise/quote', { query })
    if (version !== quoteVersion || key !== quoteKey())
      return
    state.sentBrl = quote.sendAmount
    state.feeBrl = quote.fee
    state.receivedEur = quote.receivedAmount
  }
  catch (error) {
    if (version === quoteVersion)
      quoteError.value = errorMessage(error)
  }
  finally {
    if (version === quoteVersion)
      quoting.value = false
  }
}

watch(open, (isOpen) => {
  if (isOpen)
    return
  quoteVersion++
  quoting.value = false
})

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
    description="A cotação da Wise é só uma ajuda. Ajuste os valores para o que aconteceu de fato."
    :ui="{ footer: 'justify-end' }"
  >
    <template #body>
      <UForm id="conversion-form" :schema="createConversionSchema" :state="state" class="space-y-5" @submit="submit">
        <UFormField name="day" label="Dia">
          <UInputNumber v-model="state.day" :min="1" :max="maxDay" :format-options="{ useGrouping: false }" class="w-full" />
        </UFormField>

        <div class="space-y-2">
          <span class="text-sm font-medium text-default">Cotação a partir de</span>
          <UFieldGroup class="w-full" aria-label="Valor usado para cotar">
            <UButton
              label="EUR recebido"
              class="flex-1 justify-center"
              color="neutral"
              :variant="mode === 'EUR' ? 'solid' : 'outline'"
              :aria-pressed="mode === 'EUR'"
              @click="mode = 'EUR'"
            />
            <UButton
              label="BRL enviado"
              class="flex-1 justify-center"
              color="neutral"
              :variant="mode === 'BRL' ? 'solid' : 'outline'"
              :aria-pressed="mode === 'BRL'"
              @click="mode = 'BRL'"
            />
          </UFieldGroup>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField name="receivedEur" label="EUR recebido">
            <UInputNumber
              v-model="state.receivedEur"
              :min="0"
              :step="0.01"
              locale="pt-BR"
              :format-options="{ style: 'currency', currency: 'EUR', currencyDisplay: 'narrowSymbol' }"
              class="w-full"
              :highlight="mode === 'EUR'"
            />
          </UFormField>
          <UFormField name="sentBrl" label="BRL enviado">
            <UInputNumber
              v-model="state.sentBrl"
              :min="0"
              :step="0.01"
              locale="pt-BR"
              :format-options="{ style: 'currency', currency: 'BRL', currencyDisplay: 'narrowSymbol' }"
              class="w-full"
              :highlight="mode === 'BRL'"
            />
          </UFormField>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <UButton
            label="Calcular com a Wise"
            icon="i-lucide-sparkles"
            color="neutral"
            variant="subtle"
            size="sm"
            :loading="quoting"
            :disabled="!quoteKey()"
            @click="requestQuote()"
          />
          <p class="text-xs text-muted">
            Preenche o outro valor e a taxa a partir do {{ mode === 'EUR' ? 'EUR recebido' : 'BRL enviado' }}. Os três continuam editáveis.
          </p>
        </div>

        <UAlert
          v-if="quoteError"
          color="error"
          variant="subtle"
          icon="i-lucide-circle-alert"
          title="Não foi possível consultar a Wise"
          :description="quoteError"
          :actions="[{ label: 'Tentar novamente', color: 'neutral', variant: 'outline', icon: 'i-lucide-refresh-cw', onClick: () => requestQuote() }]"
        />

        <UFormField name="feeBrl" label="Taxa Wise em BRL">
          <UInputNumber
            v-model="state.feeBrl"
            :min="0"
            :step="0.01"
            locale="pt-BR"
            :format-options="{ style: 'currency', currency: 'BRL', currencyDisplay: 'narrowSymbol' }"
            class="w-full"
          />
        </UFormField>

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
