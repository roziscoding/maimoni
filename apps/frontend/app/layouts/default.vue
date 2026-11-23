<script setup lang="ts">
import type { MonthListEntry } from '@maimoni/shared'
import type { DropdownMenuItem, NavigationMenuItem } from '@nuxt/ui'
import { monthPhase } from '@maimoni/shared'

const { data: months } = await useFetch<MonthListEntry[]>('/api/months', { key: 'months', default: () => [] })
const creating = useState('new-month-open', () => false)

const toast = useToast()
const { user, signOut } = useAuth()
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

/** Months grouped under a year label, newest first, each showing what is left, in the currency it is worked out in. */
const monthItems = computed<NavigationMenuItem[]>(() => {
  const items: NavigationMenuItem[] = []
  let year: number | undefined
  for (const entry of months.value) {
    if (entry.year !== year) {
      year = entry.year
      items.push({ label: String(year), type: 'label' })
    }
    items.push({
      label: monthName(entry.month),
      to: `/months/${entry.year}/${entry.month}`,
      icon: monthPhase(entry.year, entry.month) === 'current' ? 'i-lucide-calendar-check' : 'i-lucide-calendar',
      net: entry.summary.net,
      currency: entry.summary.main,
      current: monthPhase(entry.year, entry.month) === 'current',
    })
  }
  return items
})

const todayItems = computed<NavigationMenuItem[]>(() => {
  const current = months.value.find(entry => monthPhase(entry.year, entry.month) === 'current')
  return [
    { label: 'Gastos diários', icon: 'i-lucide-wallet', to: '/', net: current?.summary.allowance.remaining ?? null, currency: current?.summary.main },
  ]
})

const displayName = computed(() => user.value?.name || user.value?.email || '')

/** The menu behind the user button: who is signed in, the pages that aren't months, and sign out. */
const userItems = computed<DropdownMenuItem[][]>(() => [
  [{
    type: 'label',
    label: displayName.value,
    description: user.value?.name ? user.value.email : undefined,
    ui: { label: 'px-2.5 py-2', itemDescription: 'text-xs font-normal' },
  }],
  [
    { label: 'Template', icon: 'i-lucide-layout-template', to: '/template' },
    { label: 'Configurações', icon: 'i-lucide-settings-2', to: '/settings' },
    { label: 'Sair', icon: 'i-lucide-log-out', color: 'error', onSelect: leave },
  ],
])
</script>

<template>
  <UDashboardGroup unit="rem">
    <UDashboardSidebar
      resizable
      :default-size="17"
      :min-size="14"
      :max-size="24"
      class="bg-elevated/40"
      :ui="{ footer: 'border-t border-default' }"
    >
      <template #header>
        <NuxtLink to="/" class="flex items-baseline gap-1.5 px-1 text-lg font-semibold tracking-tight text-highlighted">
          maimoni
        </NuxtLink>
      </template>

      <template #default>
        <UNavigationMenu :items="todayItems" orientation="vertical" aria-label="Gastos do dia" :ui="{ linkTrailing: 'ms-auto' }">
          <template #item-trailing="{ item }">
            <span
              v-if="item.net !== null"
              class="money text-xs"
              :class="item.net < 0 ? 'text-error' : 'text-muted'"
            >{{ formatMoney(item.net, item.currency) }}</span>
          </template>
        </UNavigationMenu>

        <UButton
          label="Novo mês"
          icon="i-lucide-plus"
          color="neutral"
          variant="subtle"
          block
          class="mb-2"
          @click="creating = true"
        />

        <UNavigationMenu
          v-if="monthItems.length"
          :items="monthItems"
          orientation="vertical"
          aria-label="Meses"
          :ui="{ linkTrailing: 'ms-auto' }"
        >
          <template #item-label="{ item }">
            <span :class="{ 'font-semibold text-highlighted': item.current }">{{ item.label }}</span>
          </template>
          <template #item-trailing="{ item }">
            <span
              v-if="item.to"
              class="money text-xs"
              :class="item.net === null ? 'text-dimmed' : item.net < 0 ? 'text-error' : 'text-muted'"
            >{{ formatMoney(item.net, item.currency) }}</span>
          </template>
        </UNavigationMenu>
        <p v-else class="px-2.5 py-2 text-sm text-muted">
          Nenhum mês ainda.
        </p>
      </template>

      <template #footer>
        <div class="flex w-full items-center gap-1">
          <UDropdownMenu
            :items="userItems"
            :content="{ side: 'top', align: 'start' }"
            :ui="{ content: 'w-60 rounded-xl' }"
          >
            <UButton
              :avatar="{ src: user?.image ?? undefined, alt: displayName }"
              :label="displayName"
              color="neutral"
              variant="ghost"
              :loading="leaving"
              class="min-w-0 flex-1 justify-start gap-2.5 p-1.5 data-[state=open]:bg-elevated"
              :ui="{ leadingAvatarSize: 'md' }"
            />
          </UDropdownMenu>
          <UColorModeButton />
        </div>
      </template>
    </UDashboardSidebar>

    <slot />

    <NewMonthModal v-model:open="creating" :months="months" />
  </UDashboardGroup>
</template>
