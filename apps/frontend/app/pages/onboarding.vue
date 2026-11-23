<script setup lang="ts">
import type { CreateMonth, CurrenciesInUseError, Currency, MonthDetail, MonthListEntry, ReplaceUserCurrencies, UserCurrency } from '@maimoni/shared'
import { currencies as knownCurrencies } from '@maimoni/shared'

definePageMeta({ layout: false })

useHead({ title: 'Boas-vindas · maimoni' })

const toast = useToast()
const { user, finishOnboarding, signOut } = useAuth()
/** What to call the user. A user added by hand may have their email for a name, which isn't one to greet by. */
const firstName = computed(() => {
  const name = user.value?.name.trim().split(/\s+/)[0]
  return name && !name.includes('@') ? name : null
})

const template = useTemplate()
const { items, addItem, removeItem } = template
// Same key as `useCurrencies`, so what the template offers follows the currencies saved here.
const currencies = useFetch<UserCurrency[]>('/api/settings/currencies', { key: 'currencies' })
const { data: savedCurrencies } = currencies
const monthList = useFetch<MonthListEntry[]>('/api/months', { key: 'months', default: () => [] })
const { data: months, refresh: refreshMonths } = monthList
await Promise.all([template.ready, currencies, monthList])

/* ---------------------------------- Steps --------------------------------- */

/** `done` comes after the setup is recorded as finished: there is no going back from it, only into the app. */
type Step = 'welcome' | 'currencies' | 'main' | 'income' | 'expenses' | 'month' | 'done'

const saved = savedCurrencies.value ?? []
/** The currencies the user says they use, in the order they chose them. */
const picked = ref<Currency[]>(saved.filter(entry => entry.enabled).toSorted((a, b) => Number(b.main) - Number(a.main)).map(entry => entry.currency))
/** The main currency, as the one-item list the tiles work with. */
const mainPick = ref<Currency[]>(saved.filter(entry => entry.main).map(entry => entry.currency))

/** A user who already has currencies left in the middle, so they come back to the question after them. */
const step = ref<Step>(saved.length ? 'income' : 'welcome')

/** The questions the progress bar counts. With a single currency there is no main one to ask about. */
const flow = computed<Step[]>(() => ['currencies', ...(picked.value.length > 1 ? ['main' as const] : []), 'income', 'expenses', 'month'])
const position = computed(() => flow.value.indexOf(step.value))

function back() {
  step.value = flow.value[position.value - 1] ?? 'welcome'
}

// Each question takes the place of the last one, so focus moves to its heading for it to be read out.
const heading = useTemplateRef<HTMLElement>('heading')
watch(step, () => nextTick(() => heading.value?.focus()), { flush: 'post' })

/* ------------------------------- Currencies ------------------------------- */

const savingCurrencies = ref(false)

async function saveCurrencies() {
  const main = mainPick.value[0]
  if (!main)
    return
  savingCurrencies.value = true
  try {
    const body: ReplaceUserCurrencies = {
      currencies: [
        ...picked.value.map(currency => ({ currency, enabled: true })),
        // A currency disabled somewhere else isn't asked about here, and leaving it out would remove it.
        ...(savedCurrencies.value ?? []).filter(entry => !entry.enabled && !picked.value.includes(entry.currency)).map(entry => ({ currency: entry.currency, enabled: false })),
      ],
      main,
    }
    savedCurrencies.value = await $fetch<UserCurrency[]>('/api/settings/currencies', { method: 'PUT', body })
    // The rates are quoted against the main currency, which may have just changed.
    await refreshNuxtData('live-rates')
    step.value = 'income'
  }
  catch (error) {
    // Going back and unmarking a currency that already has entries or expenses in it.
    const inUse = (error as { data?: Partial<CurrenciesInUseError> } | null)?.data?.inUse
    toast.add(inUse?.length
      ? { title: 'Essa moeda ainda tem valores', description: `Remova as entradas e saídas em ${inUse.map(currencyName).join(', ')} antes de desmarcar.`, color: 'error', icon: 'i-lucide-circle-alert' }
      : { title: 'Não foi possível salvar suas moedas', description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    savingCurrencies.value = false
  }
}

async function currenciesChosen() {
  // The main one stays when it is still among the chosen; otherwise it is the first one chosen, likely the user's own.
  if (!mainPick.value[0] || !picked.value.includes(mainPick.value[0]))
    mainPick.value = picked.value.slice(0, 1)
  if (picked.value.length > 1)
    step.value = 'main'
  else
    await saveCurrencies()
}

/* -------------------------------- Template -------------------------------- */

const offered = computed(() => template.currencies.offered.value)
const mainCurrency = computed(() => template.currencies.main.value)
const incomes = computed(() => items.value.filter(item => item.kind === 'income'))
const expenses = computed(() => items.value.filter(item => item.kind === 'expense'))

const itemsForm = useTemplateRef('itemsForm')

/** Moves on from a list of items, first adding what was typed and not added. */
async function itemsDone(next: Step) {
  if (await itemsForm.value?.commitPending() ?? true)
    step.value = next
}

/* ---------------------------------- Month --------------------------------- */

const now = new Date()
const year = now.getFullYear()
const month = now.getMonth() + 1
const monthLower = monthName(month).toLowerCase()
// Read once: the question describes the month as it was when the setup opened, and must not change
// into "already exists" while the month is being created.
const monthExists = months.value.some(entry => entry.year === year && entry.month === month)
/** Whether this screen created the month. A second try after a failure doesn't create it again. */
const monthCreated = ref(false)
/** The current month as the template would make it. */
const summary = computed(() => template.summaryFor(year, month))
const allowance = computed(() => summary.value?.allowance ?? null)

/** What is running: finishing with the month, or finishing without it. */
const pending = ref<'month' | 'later' | null>(null)

/** Records the setup as finished and shows the last screen. `month` makes the current month first, unless it exists. */
async function finish(action: 'month' | 'later') {
  pending.value = action
  let failure = 'Não foi possível concluir'
  try {
    if (action === 'month' && !monthExists && !monthCreated.value) {
      failure = `Não foi possível criar ${monthLower}`
      await $fetch<MonthDetail>('/api/months', { method: 'POST', body: { year, month, source: 'template' } satisfies CreateMonth })
      monthCreated.value = true
      // For the sidebar the user lands on, which reads the same list.
      await refreshMonths()
      failure = `${monthName(month)} foi criado, mas não foi possível concluir`
    }
    await finishOnboarding()
    step.value = 'done'
  }
  catch (error) {
    toast.add({ title: failure, description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    pending.value = null
  }
}

const leaving = ref(false)
async function leave() {
  leaving.value = true
  try {
    await signOut()
  }
  catch (error) {
    toast.add({ title: 'Não foi possível sair', description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
  }
  finally {
    leaving.value = false
  }
}
</script>

<template>
  <!-- Over the page instead of above it, so the card is centered on the whole screen. -->
  <header class="absolute inset-x-0 top-0 flex items-center justify-between px-4 py-3 sm:px-6">
    <span class="text-lg font-semibold tracking-tight text-highlighted">maimoni</span>
    <UButton label="Sair" icon="i-lucide-log-out" color="neutral" variant="outline" size="sm" :loading="leaving" @click="leave" />
  </header>

  <!-- The same padding on both ends keeps the card centered and clear of the header on a short screen. -->
  <main class="flex min-h-dvh items-center justify-center px-4 py-16">
    <UPageCard class="w-full max-w-lg">
      <div class="space-y-6">
        <!-- One segment per question still to come. Nothing to count on the welcome, which isn't one. -->
        <div
          v-if="position >= 0"
          role="progressbar"
          aria-label="Perguntas respondidas"
          :aria-valuenow="position"
          aria-valuemin="0"
          :aria-valuemax="flow.length"
          class="flex gap-1.5"
        >
          <span
            v-for="(entry, index) in flow"
            :key="entry"
            class="h-1 flex-1 rounded-full transition-colors duration-300"
            :class="index <= position ? 'bg-primary' : 'bg-accented'"
          />
        </div>

        <Transition name="step" mode="out-in">
          <section v-if="step === 'welcome'" key="welcome" class="space-y-6">
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                Boas-vindas ao maimoni
              </h1>
              <p class="text-muted">
                O maimoni divide o que sobra do seu mês pelos dias que faltam e mostra quanto você pode gastar hoje.
              </p>
              <p class="text-muted">
                Para fazer essa conta, ele precisa saber algumas coisas sobre o seu dinheiro.
              </p>
            </div>
            <div class="flex justify-end">
              <UButton label="Começar" autofocus @click="step = 'currencies'" />
            </div>
          </section>

          <section v-else-if="step === 'currencies'" key="currencies" class="space-y-6">
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                Quais moedas você usa?
              </h1>
              <p class="text-muted">
                O maimoni controla seus gastos em mais de uma moeda ao mesmo tempo. Marque todas as que fazem parte do seu mês.
              </p>
            </div>
            <CurrencyTiles v-model="picked" :options="[...knownCurrencies]" :pinned="['BRL', 'EUR', 'USD']" multiple label="Moedas que você usa" />
            <div class="flex items-center justify-between">
              <UButton label="Voltar" color="neutral" variant="ghost" :disabled="savingCurrencies" @click="back" />
              <UButton label="Continuar" :loading="savingCurrencies" :disabled="!picked.length" @click="currenciesChosen" />
            </div>
          </section>

          <section v-else-if="step === 'main'" key="main" class="space-y-6">
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                Qual delas é a principal?
              </h1>
              <p class="text-muted">
                É a moeda do seu dia a dia. O valor que você pode gastar por dia é calculado nela, e o que estiver nas outras é convertido.
              </p>
            </div>
            <CurrencyTiles v-model="mainPick" :options="picked" label="Moeda principal" />
            <div class="flex items-center justify-between">
              <UButton label="Voltar" color="neutral" variant="ghost" :disabled="savingCurrencies" @click="back" />
              <UButton label="Continuar" :loading="savingCurrencies" :disabled="!mainPick.length" @click="saveCurrencies" />
            </div>
          </section>

          <section v-else-if="step === 'income'" key="income" class="space-y-6">
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                O que entra todo mês?
              </h1>
              <p class="text-muted">
                Seu salário e qualquer outro valor que você recebe sempre. Todo mês novo já começa com essas entradas.
              </p>
            </div>
            <OnboardingItems
              ref="itemsForm"
              kind="income"
              :items="incomes"
              :currencies="offered"
              :main="mainCurrency"
              example="Salário"
              @add="addItem"
              @remove="removeItem"
            />
            <div class="flex items-center justify-between">
              <UButton label="Voltar" color="neutral" variant="ghost" @click="back" />
              <UButton label="Pular" color="neutral" variant="ghost" @click="step = 'expenses'" />
              <UButton label="Continuar" :disabled="!incomes.length && !itemsForm?.hasDraft" @click="itemsDone('expenses')" />
            </div>
          </section>

          <section v-else-if="step === 'expenses'" key="expenses" class="space-y-6">
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                E o que sai todo mês?
              </h1>
              <p class="text-muted">
                As contas fixas, como aluguel e internet. Os gastos do dia a dia ficam de fora: você registra cada um quando acontece.
              </p>
            </div>
            <OnboardingItems
              ref="itemsForm"
              kind="expense"
              :items="expenses"
              :currencies="offered"
              :main="mainCurrency"
              example="Aluguel"
              @add="addItem"
              @remove="removeItem"
            />
            <div class="flex items-center justify-between">
              <UButton label="Voltar" color="neutral" variant="ghost" @click="back" />
              <UButton label="Pular" color="neutral" variant="ghost" @click="step = 'month'" />
              <UButton label="Continuar" :disabled="!expenses.length && !itemsForm?.hasDraft" @click="itemsDone('month')" />
            </div>
          </section>

          <section v-else-if="step === 'month'" key="month" class="space-y-6">
            <div v-if="monthExists" class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                {{ monthName(month) }} já está criado
              </h1>
              <p class="text-muted">
                Você já tem esse mês, então não precisa criar de novo.
              </p>
            </div>

            <!-- What the answers add up to: the figure the app is about. -->
            <div v-else-if="items.length && summary && allowance && allowance.amount !== null" class="space-y-4">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                Em {{ monthLower }}, você pode gastar
              </h1>
              <p class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <span class="money text-5xl font-semibold leading-none tracking-tight sm:text-6xl" :class="allowance.amount < 0 ? 'text-error' : 'text-highlighted'">
                  {{ formatMoney(allowance.amount, summary.main) }}
                </span>
                <span class="text-muted">por dia</span>
              </p>
              <p class="text-muted">
                <template v-if="(summary.net ?? 0) >= 0">
                  Sobram <span class="money text-toned">{{ formatMoney(summary.net, summary.main) }}</span> depois das contas,
                </template>
                <template v-else>
                  As contas passam das entradas em <span class="money text-toned">{{ formatMoney(-(summary.net ?? 0), summary.main) }}</span>,
                </template>
                {{ allowance.days === 1 ? 'e falta 1 dia para o mês acabar.' : `divididos pelos ${allowance.days} dias que faltam para o mês acabar.` }}
              </p>
            </div>

            <div v-else class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                Criar o mês de {{ monthLower }}?
              </h1>
              <p v-if="items.length" class="text-muted">
                Não deu para calcular seu valor diário agora, porque a cotação das moedas não carregou. Ele aparece no mês assim que a cotação voltar.
              </p>
              <p v-else class="text-muted">
                Você pode adicionar suas entradas e saídas direto no mês, quando quiser.
              </p>
            </div>

            <div class="flex flex-wrap items-center justify-between gap-2">
              <UButton label="Voltar" color="neutral" variant="ghost" :disabled="pending !== null" @click="back" />
              <div class="flex items-center gap-2">
                <UButton
                  v-if="!monthExists"
                  label="Agora não"
                  color="neutral"
                  variant="outline"
                  :loading="pending === 'later'"
                  :disabled="pending !== null"
                  @click="finish('later')"
                />
                <UButton
                  :label="monthExists ? 'Concluir' : `Criar ${monthLower}`"
                  :loading="pending === 'month'"
                  :disabled="pending !== null"
                  @click="finish('month')"
                />
              </div>
            </div>
          </section>

          <!-- The setup is recorded as finished by now. Leaving is the user's click, never a redirect of its own. -->
          <section v-else key="done" class="space-y-6">
            <span class="grid size-10 place-items-center rounded-full bg-primary text-inverted" aria-hidden="true">
              <UIcon name="i-lucide-check" class="size-5" />
            </span>
            <div class="space-y-2">
              <h1 ref="heading" tabindex="-1" class="text-2xl font-semibold tracking-tight text-highlighted outline-none">
                {{ firstName ? `Tudo pronto, ${firstName}` : 'Tudo pronto' }}
              </h1>
              <p v-if="monthExists || monthCreated" class="text-muted">
                Registre seus gastos conforme eles acontecem e feche o dia quando ele acabar. O que sobrar hoje vira folga nos próximos dias.
              </p>
              <p v-else class="text-muted">
                Suas moedas e seus valores de todo mês já estão guardados. Quando quiser começar, crie o mês de {{ monthLower }} na tela inicial.
              </p>
            </div>
            <div class="flex justify-end">
              <UButton :label="monthExists || monthCreated ? 'Registrar um gasto' : 'Abrir o maimoni'" autofocus to="/" />
            </div>
          </section>
        </Transition>
      </div>
    </UPageCard>
  </main>
</template>

<style scoped>
/* One question gives way to the next. The global reduced-motion rule shortens it to nothing. */
.step-enter-active,
.step-leave-active {
  transition: opacity 150ms ease, transform 150ms ease;
}
.step-enter-from {
  opacity: 0;
  transform: translateX(0.5rem);
}
.step-leave-to {
  opacity: 0;
  transform: translateX(-0.5rem);
}
</style>
