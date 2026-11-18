import type { Conversion, CreateConversion, CreateDailySpend, CreateMonthItem, DailySpend, LiveRate, MonthDetail, MonthItem, MonthListEntry, TemplateItem, UpdateConversion, UpdateDailySpend, UpdateMonth, UpdateMonthItem } from '@maimoni/shared'
import { nextActiveDay, summarizeMonth } from '@maimoni/shared'

const RATE_REFRESH_MS = 5 * 60 * 1000

/**
 * Loads one month and exposes optimistic mutations: local state changes first (so the
 * summary recomputes instantly), then the request is sent; on failure a toast is shown
 * and the month is refetched.
 */
export async function useMonth(year: number, month: number) {
  const toast = useToast()
  const base = `/api/months/${year}/${month}`
  // Not awaited yet: lifecycle hooks below must register while the component instance is still active.
  const fetched = useFetch<MonthDetail>(base, { key: `month-${year}-${month}` })
  const { data, error, refresh } = fetched
  const { data: months } = useNuxtData<MonthListEntry[]>('months')

  const summary = computed(() => data.value
    ? summarizeMonth(data.value.month, data.value.items, {
        rate: data.value.rate?.rate ?? null,
        spends: data.value.spends,
        conversions: data.value.conversions,
      })
    : null)

  // Keep the sidebar's net figure in sync without refetching the whole list.
  watch(summary, (value) => {
    if (!value || !months.value)
      return
    months.value = months.value.map(entry => entry.year === year && entry.month === month ? { ...entry, summary: value } : entry)
  })

  function setItems(update: (items: MonthItem[]) => MonthItem[]) {
    if (data.value)
      data.value = { ...data.value, items: update(data.value.items) }
  }

  async function persist<T>(request: () => Promise<T>): Promise<T | undefined> {
    try {
      return await request()
    }
    catch (error) {
      toast.add({ title: 'Não foi possível salvar', description: errorMessage(error), color: 'error', icon: 'i-lucide-circle-alert' })
      await refresh()
    }
  }

  async function updateItem(id: string, patch: UpdateMonthItem) {
    setItems(items => items.map(item => item.id === id
      ? { ...item, ...patch, needsReview: patch.needsReview ?? ('amount' in patch ? false : item.needsReview) } as MonthItem
      : item))
    const saved = await persist(() => $fetch<MonthItem>(`${base}/items/${id}`, { method: 'PATCH', body: patch }))
    if (saved)
      setItems(items => items.map(item => item.id === id ? saved : item))
  }

  async function addItem(body: CreateMonthItem) {
    const created = await persist(() => $fetch<MonthItem>(`${base}/items`, { method: 'POST', body }))
    if (created)
      setItems(items => [...items, created])
  }

  async function removeItem(id: string) {
    setItems(items => items.filter(item => item.id !== id))
    await persist(() => $fetch(`${base}/items/${id}`, { method: 'DELETE' }))
  }

  async function promoteItem(id: string) {
    const promoted = await persist(() => $fetch<TemplateItem>(`${base}/items/${id}/promote`, { method: 'POST' }))
    if (!promoted)
      return
    setItems(items => items.map(item => item.id === id ? { ...item, templateItemId: promoted.id } : item))
    toast.add({ title: 'Salvo no template', description: `${promoted.name} vai aparecer nos próximos meses.`, color: 'success', icon: 'i-lucide-check' })
  }

  async function updateMonth(patch: UpdateMonth) {
    if (data.value)
      data.value = { ...data.value, month: { ...data.value.month, ...patch } as MonthDetail['month'] }
    const saved = await persist(() => $fetch<MonthDetail>(base, { method: 'PATCH', body: patch }))
    if (saved && data.value)
      data.value = { ...data.value, month: saved.month }
  }

  async function removeMonth() {
    await $fetch(base, { method: 'DELETE' })
    await refreshNuxtData('months')
  }

  function setSpends(update: (spends: DailySpend[]) => DailySpend[]) {
    if (data.value)
      data.value = { ...data.value, spends: update(data.value.spends) }
  }

  async function addSpend(body: CreateDailySpend) {
    const created = await persist(() => $fetch<DailySpend>(`${base}/spends`, { method: 'POST', body }))
    if (created)
      setSpends(spends => [...spends, created])
    return created
  }

  async function updateSpend(id: string, patch: UpdateDailySpend) {
    setSpends(spends => spends.map(spend => spend.id === id ? { ...spend, ...patch } as DailySpend : spend))
    const saved = await persist(() => $fetch<DailySpend>(`${base}/spends/${id}`, { method: 'PATCH', body: patch }))
    if (saved)
      setSpends(spends => spends.map(spend => spend.id === id ? saved : spend))
  }

  async function removeSpend(id: string) {
    setSpends(spends => spends.filter(spend => spend.id !== id))
    await persist(() => $fetch(`${base}/spends/${id}`, { method: 'DELETE' }))
  }

  function setConversions(update: (conversions: Conversion[]) => Conversion[]) {
    if (data.value)
      data.value = { ...data.value, conversions: update(data.value.conversions) }
  }

  async function addConversion(body: CreateConversion) {
    const created = await persist(() => $fetch<Conversion>(`${base}/conversions`, { method: 'POST', body }))
    if (created)
      setConversions(conversions => [...conversions, created])
    return created
  }

  async function updateConversion(id: string, patch: UpdateConversion) {
    setConversions(conversions => conversions.map(conversion => conversion.id === id ? { ...conversion, ...patch } as Conversion : conversion))
    const saved = await persist(() => $fetch<Conversion>(`${base}/conversions/${id}`, { method: 'PATCH', body: patch }))
    if (saved)
      setConversions(conversions => conversions.map(conversion => conversion.id === id ? saved : conversion))
    return saved
  }

  async function removeConversion(id: string) {
    setConversions(conversions => conversions.filter(conversion => conversion.id !== id))
    await persist(() => $fetch(`${base}/conversions/${id}`, { method: 'DELETE' }))
  }

  const refreshingRate = ref(false)
  async function refreshRate(refreshMonths = true) {
    refreshingRate.value = true
    try {
      const rate = await $fetch<LiveRate>('/api/rates/live')
      if (data.value)
        data.value = { ...data.value, rate, rateError: null }
      if (refreshMonths)
        await refreshNuxtData('months')
      return rate
    }
    catch (error) {
      if (data.value)
        data.value = { ...data.value, rateError: errorMessage(error) }
      return null
    }
    finally {
      refreshingRate.value = false
    }
  }

  /** Moves the open day forward (to today, or to tomorrow if today is open); returns the previous value for undo. */
  async function closeDay() {
    if (!data.value)
      return
    const previous = data.value.month.activeDay
    const next = nextActiveDay(data.value.month)
    if (next === null)
      return
    await updateMonth({ activeDay: next })
    return previous
  }

  // While the page is open, keep the live rate fresh (it drives the allowance when the rate isn't locked).
  let timer: ReturnType<typeof setInterval> | undefined
  onMounted(() => {
    timer = setInterval(async () => {
      await refreshRate(false)
    }, RATE_REFRESH_MS)
  })
  onBeforeUnmount(() => {
    clearInterval(timer)
  })

  await fetched
  // Not spreading `fetched`: it is thenable, so awaiting this object would resolve to the bare AsyncData.
  return { data, error, summary, refreshingRate, refreshRate, updateItem, addItem, removeItem, promoteItem, updateMonth, removeMonth, addSpend, updateSpend, removeSpend, addConversion, updateConversion, removeConversion, closeDay }
}
