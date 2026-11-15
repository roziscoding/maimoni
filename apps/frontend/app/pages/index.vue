<script setup lang="ts">
import type { DailySpend, MonthListEntry } from '@maimoni/shared'
import { nextActiveDay, spendInEur, summarizeMonth } from '@maimoni/shared'

definePageMeta({ key: route => route.fullPath })

useHead({ title: 'Gastos diários · maimoni' })

const now = new Date()
const year = now.getFullYear()
const month = now.getMonth() + 1

const toast = useToast()
const { data, error, summary, refreshingRate, refreshRate, addSpend, updateSpend, removeSpend, closeDay, updateMonth } = await useMonth(year, month)
const { data: months } = useNuxtData<MonthListEntry[]>('months')
const hasPrevious = computed(() => months.value?.some(entry => entry.year * 12 + entry.month < year * 12 + month) ?? false)

const allowance = computed(() => summary.value?.allowance)
const activeDay = computed(() => allowance.value?.activeDay ?? null)
/** Days before today that were never closed: their budget hasn't been spread yet. */
const lagging = computed(() => activeDay.value !== null && activeDay.value < now.getDate())

/** A spend's cost to the EUR allowance (reais are converted the way the allowance counts them). */
const inEur = (spend: DailySpend) => summary.value ? spendInEur(spend, summary.value.transfer) : null

const spendsToday = computed(() => data.value?.spends.filter(spend => spend.day === activeDay.value) ?? [])

/* -------------------------------- Close day ------------------------------- */

const next = computed(() => data.value ? nextActiveDay(data.value.month) : null)
/** The summary as it will look once the day is closed: same data, open day moved forward. */
const afterClose = computed(() => {
  if (!data.value || next.value === null)
    return null
  const { month: current, items, spends, rate, quote, fallbackFee } = data.value
  return summarizeMonth({ ...current, activeDay: next.value }, items, { rate: rate?.rate ?? null, quote, fallbackFee, spends }).allowance
})
const closing = ref(false)
const confirmingClose = ref(false)

async function confirmClose() {
  closing.value = true
  const closedDay = activeDay.value
  const previous = await closeDay()
  closing.value = false
  confirmingClose.value = false
  if (closedDay === null)
    return
  toast.add({
    title: `Dia ${closedDay} fechado`,
    description: summary.value?.allowance.eur == null ? undefined : `Novo valor diário: ${formatMoney(summary.value.allowance.eur, 'EUR')}.`,
    color: 'neutral',
    icon: 'i-lucide-calendar-check',
    // Long enough to notice a misclick and undo it.
    duration: 10_000,
    actions: [{ label: 'Desfazer', color: 'neutral', variant: 'outline', onClick: () => updateMonth({ activeDay: previous ?? null }) }],
  })
}
</script>

<template>
  <UDashboardPanel id="today">
    <template #header>
      <UDashboardNavbar :title="activeDay === null ? 'Hoje' : dayLabel(year, month, activeDay)">
        <template v-if="next !== null && activeDay !== null" #right>
          <UButton
            label="Fechar o dia"
            icon="i-lucide-calendar-check"
            color="neutral"
            :variant="lagging ? 'solid' : 'outline'"
            @click="confirmingClose = true"
          />
        </template>
      </UDashboardNavbar>
    </template>

    <template #body>
      <div v-if="data && allowance" class="mx-auto w-full max-w-2xl space-y-10 py-2">
        <UAlert
          v-if="lagging"
          color="warning"
          variant="subtle"
          icon="i-lucide-calendar-clock"
          :title="`O dia ${activeDay} ainda está aberto`"
          description="Gastos novos entram nele. Feche o dia para levar a sobra (ou o que passou) para os dias que faltam."
        />

        <template v-if="activeDay !== null && allowance.eur !== null">
          <DayHero v-if="summary" :allowance="allowance" :spends="spendsToday" :transfer="summary.transfer" />

          <SpendForm :day="activeDay" :create="addSpend" autofocus />

          <section v-if="spendsToday.length" aria-labelledby="today-spends" class="space-y-2">
            <div class="flex items-baseline justify-between">
              <h2 id="today-spends" class="text-sm font-medium text-muted">
                Gastos do dia
              </h2>
              <span class="money text-sm text-muted">{{ formatMoney(allowance.spentToday, 'EUR') }}</span>
            </div>
            <ul class="divide-y divide-default">
              <SpendRow
                v-for="spend in spendsToday"
                :key="spend.id"
                :spend="spend"
                :eur="inEur(spend)"
                @update="updateSpend(spend.id, $event)"
                @remove="removeSpend(spend.id)"
              />
            </ul>
          </section>

          <p class="text-sm text-muted">
            O mês tem <span class="money text-toned">{{ formatMoney(summary?.eur.net, 'EUR') }}</span> livres depois das contas.
            <template v-if="allowance.spentBefore">
              Já foram <span class="money text-toned">{{ formatMoney(allowance.spentBefore, 'EUR') }}</span> nos
              <NuxtLink to="/?view=calendar" class="underline decoration-dotted underline-offset-2 hover:text-default">
                dias anteriores
              </NuxtLink>,
            </template>
            <template v-else>
              Isso
            </template>
            dividido por {{ allowance.days }} {{ allowance.days === 1 ? 'dia' : 'dias' }} dá
            <span class="money text-toned">{{ formatMoney(allowance.eur, 'EUR') }}</span> por dia.
          </p>
        </template>

        <UEmpty
          v-else-if="activeDay === null"
          icon="i-lucide-flag"
          :title="`Todos os dias de ${monthName(month).toLowerCase()} foram fechados`"
          :description="`No mês, os gastos do dia a dia somaram ${formatMoney(allowance.spentTotal, 'EUR')}.`"
          variant="naked"
        />

        <UEmpty
          v-else
          icon="i-lucide-hourglass"
          title="Ainda não dá para calcular o dia"
          :description="data.rateError ? `A cotação do euro falhou: ${data.rateError}` : 'Falta a cotação do euro.'"
          variant="naked"
        >
          <template #actions>
            <UButton
              label="Tentar novamente"
              icon="i-lucide-refresh-cw"
              color="neutral"
              variant="subtle"
              :loading="refreshingRate"
              @click="refreshRate()"
            />
          </template>
        </UEmpty>

      </div>

      <MonthCreate v-else-if="error?.statusCode === 404" :year="year" :month="month" :has-previous="hasPrevious" class="my-auto" />

      <UEmpty
        v-else-if="error"
        icon="i-lucide-cloud-off"
        title="Não foi possível carregar o mês"
        :description="errorMessage(error)"
        variant="naked"
        class="my-auto"
      />

      <DailySpendHistory />

      <UModal
        v-model:open="confirmingClose"
        :title="activeDay === null ? 'Fechar o dia' : `Fechar o dia ${activeDay}?`"
        :ui="{ footer: 'justify-end' }"
      >
        <template v-if="allowance && afterClose" #body>
          <div class="space-y-3 text-sm">
            <p v-if="(allowance.remainingEur ?? 0) >= 0">
              Sobraram <span class="money font-semibold text-highlighted">{{ formatMoney(allowance.remainingEur, 'EUR') }}</span>.
              Eles vão para os dias que faltam.
            </p>
            <p v-else>
              O dia passou <span class="money font-semibold text-error">{{ formatMoney(-(allowance.remainingEur ?? 0), 'EUR') }}</span>.
              Isso sai dos dias que faltam.
            </p>
            <p v-if="afterClose.activeDay !== null && afterClose.eur !== null" class="rounded-lg bg-elevated p-3">
              A partir {{ afterClose.activeDay === now.getDate() ? 'de hoje' : `do dia ${afterClose.activeDay}` }}:
              <span class="money text-base font-semibold text-highlighted">{{ formatMoney(afterClose.eur, 'EUR') }}</span> por dia,
              por {{ afterClose.days }} {{ afterClose.days === 1 ? 'dia' : 'dias' }}.
            </p>
            <p v-else class="rounded-lg bg-elevated p-3">
              Era o último dia do mês.
            </p>
          </div>
        </template>
        <template #footer="{ close }">
          <UButton label="Cancelar" color="neutral" variant="outline" @click="close" />
          <UButton label="Fechar o dia" icon="i-lucide-calendar-check" :loading="closing" @click="confirmClose" />
        </template>
      </UModal>
    </template>
  </UDashboardPanel>
</template>
