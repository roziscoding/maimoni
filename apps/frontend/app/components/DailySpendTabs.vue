<script setup lang="ts">
type DailySpendView = 'calendar' | 'spends'

const props = defineProps<{
  view: DailySpendView
}>()

const route = useRoute()
const items = [
  { label: 'Calendário', icon: 'i-lucide-calendar-days', value: 'calendar' },
  { label: 'Extrato', icon: 'i-lucide-list', value: 'spends' },
]

const selected = computed({
  get: () => props.view,
  set: (view: DailySpendView) => {
    if (view === props.view)
      return
    navigateTo({
      path: '/',
      query: { ...(route.query.mes ? { mes: route.query.mes } : {}), view },
    })
  },
})
</script>

<template>
  <UTabs v-model="selected" :items="items" :content="false" color="neutral" class="w-full sm:w-fit" />
</template>
