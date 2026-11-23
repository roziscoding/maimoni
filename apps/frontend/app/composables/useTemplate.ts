import type { Currency, EntryKind, LiveRates, MonthItem, TemplateDetail, TemplateItem, UpdateTemplateItem } from '@maimoni/shared'
import type { NewItem } from '~/components/AddItemForm.vue'
import { summarizeMonth } from '@maimoni/shared'

/** A currency the template shows items under. */
export interface TemplateSection {
  currency: Currency
  title: string
  /** Whether new items can be created in it. A currency that is no longer offered still shows the items it has. */
  offered: boolean
}

/**
 * The template and its edits, for the template page and the first-run setup. An edit changes the
 * local list first, then goes to the server; when that fails a toast is shown and the template is
 * loaded again.
 *
 * `ready` resolves once the template, the rates and the currencies are loaded.
 */
export function useTemplate() {
  const toast = useToast()
  // None of these is awaited here: every composable has to be called while the component instance is still active.
  const template = useFetch<TemplateDetail>('/api/template', { key: 'template' })
  const { data, error, refresh } = template
  // Quoted against the user's main currency, which a new month would be worked out in.
  const liveRates = useFetch<LiveRates>('/api/rates/live', { key: 'live-rates' })
  const { data: rates } = liveRates
  const currencies = useCurrencies()
  const ready = Promise.all([template, liveRates, currencies.ready])

  const items = computed(() => data.value?.items.toSorted((a, b) => a.position - b.position) ?? [])

  /** A section per offered currency, and per any other the template still has items in. */
  const sections = computed<TemplateSection[]>(() => currencies.shown(items.value.map(item => item.currency)).map(currency => ({
    currency,
    title: currencyPlural(currency),
    offered: currencies.offered.value.includes(currency),
  })))
  /** With a single currency the items need no heading saying which, and a summary has no rate. */
  const exchange = computed(() => sections.value.length > 1)

  const group = (currency: Currency, kind: EntryKind) => items.value.filter(item => item.currency === currency && item.kind === kind)

  /** What a month created now from this template would look like, on that month's calendar. `null` until there is a main currency. */
  function summaryFor(year: number, month: number) {
    const mainCurrency = currencies.main.value
    if (!data.value || !mainCurrency)
      return null
    const monthItems: MonthItem[] = items.value.map(item => ({
      ...item,
      monthId: '',
      templateItemId: item.id,
      paid: false,
      needsReview: item.variable,
    }))
    return summarizeMonth(
      { year, month, mainCurrency, lockedRates: {}, activeDay: null },
      monthItems,
      // Rates quoted against another currency (the main one changed since they were loaded) don't apply.
      { rates: rates.value?.base === mainCurrency ? rates.value.rates : null },
    )
  }

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
    const neighbour = siblings[siblings.findIndex(entry => entry.id === item.id) + offset]
    if (!neighbour)
      return
    const ids = items.value.map(entry => entry.id === item.id ? neighbour.id : entry.id === neighbour.id ? item.id : entry.id)
    setItems(list => list.map(entry => ({ ...entry, position: ids.indexOf(entry.id) })))
    const saved = await persist(() => $fetch<TemplateItem[]>('/api/template/items/order', { method: 'PUT', body: { ids } }))
    if (saved)
      setItems(() => saved)
  }

  return { ready, data, error, refresh, currencies, items, sections, exchange, group, summaryFor, updateItem, addItem, removeItem, moveItem }
}
