import type { Currency, MonthDetail, UserCurrency } from '@maimoni/shared'
import { currencies as knownCurrencies } from '@maimoni/shared'

/**
 * The user's currencies, for the screens to follow: what they offer, and what stops making sense
 * with a single currency (choosing one, sections per currency, anything about the exchange rate).
 *
 * `ready` resolves once the list is loaded; a page awaits it so it doesn't first render for every currency.
 */
export function useCurrencies() {
  // Same key as the settings section, so saving there updates every screen.
  const fetched = useFetch<UserCurrency[]>('/api/settings/currencies', { key: 'currencies' })
  const { data } = fetched

  /**
   * Enabled currencies, in the app's order: the ones new items and spends can be created in.
   * Every known currency when the list couldn't be loaded, so a failed request doesn't hide anything.
   */
  const offered = computed<Currency[]>(() => {
    if (!data.value)
      return [...knownCurrencies]
    return knownCurrencies.filter(currency => data.value!.some(entry => entry.currency === currency && entry.enabled))
  })

  /** Whether the user has no currency to create anything in. */
  const none = computed(() => offered.value.length === 0)

  /** The enabled main currency: what a new spend starts in. */
  const main = computed<Currency | null>(() => data.value?.find(entry => entry.main)?.currency ?? offered.value[0] ?? null)

  /**
   * Currencies a screen has to show: the offered ones plus those its data is already in. A disabled
   * or removed currency keeps showing where it has history, so the totals match what is listed.
   */
  function shown(used: Iterable<Currency>) {
    const all = new Set([...offered.value, ...used])
    return knownCurrencies.filter(currency => all.has(currency))
  }

  /** `shown` for a month: the currencies of its items and spends. */
  function shownInMonth(detail: MonthDetail | null | undefined) {
    if (!detail)
      return shown([])
    return shown([...detail.items.map(item => item.currency), ...detail.spends.map(spend => spend.currency)])
  }

  return { ready: fetched, offered, none, main, shown, shownInMonth }
}
