# API

Base path: `/api`. JSON in, JSON out. All types live in `@maimoni/shared` (`packages/shared/src`).
Validation errors return `400 { error, issues }`; missing resources `404 { error }`; conflicts `409 { error }`.
Template items, month items and daily spends are only written in one of the user's currencies (`/api/settings/currencies`); any other answers `400 { error }`.

The frontend never calls the backend directly: Nuxt proxies `/api/**` to `NUXT_API_BASE` (see `apps/frontend/server/api/[...path].ts`).

## Authentication

Every route below except `/api/health`, `/api/sign-in-providers`, `/api/password-reset`, the app update routes and the `/api/well-known/*` association files needs a session and answers `401 { error }` without one. Data is scoped to the signed in user. The frontend serves both association files at `/.well-known/<file>`, where Android and iOS look for them.

- **Web:** the session cookie set by `/api/auth/sign-in/*`.
- **Mobile:** `Authorization: Bearer <token>`.
  - The token comes in the `set-auth-token` header of every sign in response.
  - `GET /api/auth/get-session` sends it again in the same header when it renews the session.
- **Errors:** Better Auth's own routes answer `{ message, code }`; the routes below answer `{ error }`.

`/api/auth/*` is [Better Auth's API](https://www.better-auth.com/docs/concepts/api) (`basePath: '/api/auth'`). Sign up is disabled unless `AUTH_SIGNUP_ENABLED` is `true`; otherwise users are created by hand in the database (see [`decisions.md`](decisions.md)).

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| GET | `/api/health` | | `{ ok: true }` |
| GET | `/api/sign-in-providers` | | `string[]`: the social providers whose credentials are set, e.g. `["google"]` |
| POST | `/api/password-reset` | `PasswordResetRequest` (`{ email }`) | 204, whether or not the email belongs to a user. A user with that email is sent a link, valid for 1 hour, to `/reset-password?token=...`; the page sets the new password with Better Auth's `POST /api/auth/reset-password` (`{ newPassword, token }`) |
| GET | `/api/well-known/assetlinks.json` | | Digital Asset Links statement for the Android app (404 unless `ANDROID_APP_PACKAGE` and `ANDROID_APP_CERT_SHA256` are set) |
| GET | `/api/well-known/apple-app-site-association` | | `{ webcredentials: { apps } }` (404 unless `APPLE_TEAM_ID` and `APPLE_APP_BUNDLE_IDENTIFIER` are set) |
| GET | `/api/flags` | | `Flags` (`{ purge }`): whether `DELETE /api/data` is served, so the clients know to offer it |
| GET | `/api/rates/live?base=` | | `LiveRates` (`{ base, rates, source, fetchedAt, stale }`): how many units of every other currency one unit of `base` is worth. `base` defaults to the user's main currency (409 when they have none). 503 when no provider answered and nothing is cached |
| GET | `/api/template` | | `TemplateDetail` (`{ items }`) |
| POST | `/api/template/items` | `CreateTemplateItem` | `TemplateItem` (201) |
| PATCH | `/api/template/items/:id` | `UpdateTemplateItem` | `TemplateItem` |
| DELETE | `/api/template/items/:id` | | 204 |
| PUT | `/api/template/items/order` | `{ ids: string[] }` | `TemplateItem[]` |
| GET | `/api/months` | | `MonthListEntry[]` (newest first) |
| POST | `/api/months` | `CreateMonth` (`{ year, month, source?, mainCurrency? }`) | `MonthDetail` (201, 409 if it exists, 400 for a `mainCurrency` that isn't one of the user's) |
| GET | `/api/months/:year/:month` | | `MonthDetail` |
| PATCH | `/api/months/:year/:month` | `UpdateMonth` | `MonthDetail` |
| DELETE | `/api/months/:year/:month` | | 204 |
| POST | `/api/months/:year/:month/items` | `CreateMonthItem` | `MonthItem` (201) |
| PATCH | `/api/months/:year/:month/items/:id` | `UpdateMonthItem` | `MonthItem` |
| DELETE | `/api/months/:year/:month/items/:id` | | 204 |
| PUT | `/api/months/:year/:month/items/order` | `{ ids: string[] }` | `MonthItem[]` |
| POST | `/api/months/:year/:month/items/:id/promote` | | `TemplateItem` — writes the item's name/amount/expression into the template (updates the linked template item or creates a new one and links it) |
| POST | `/api/months/:year/:month/spends` | `CreateDailySpend` (`{ day, amount, currency?, expression?, note? }`) | `DailySpend` (201) |
| PATCH | `/api/months/:year/:month/spends/:id` | `UpdateDailySpend` | `DailySpend` |
| DELETE | `/api/months/:year/:month/spends/:id` | | 204 |
| DELETE | `/api/data` | | 204 — deletes the user's months (with their items and spends), and template items; 404 unless `FLAG_ENABLE_PURGE` is `true` |
| GET | `/api/settings/currencies` | | `UserCurrency[]` (`{ currency, enabled, main, inUse }`), the main one first. `enabled` tells the clients which ones to offer; the server takes items and spends in a disabled one all the same. `inUse` says a template item, month item or daily spend is in it, so it can't be removed |
| POST | `/api/settings/currencies` | `AddUserCurrency` (`{ currency, enabled?, main? }`) | `UserCurrency` (201, 409 if already added). `main: true` makes it the main one, in place of the previous one. The user's first currency is the main one whatever `main` says, so adding it with `enabled: false` answers 409. 400 for `enabled: false` with `main: true` |
| PUT | `/api/settings/currencies` | `ReplaceUserCurrencies` (`{ currencies: { currency, enabled }[], main }`) | `UserCurrency[]` — replaces the whole list. `main` has to be one of `currencies` and enabled (400 otherwise). A currency left out is removed. When any left out is in use it answers 409 `CurrenciesInUseError` (`{ error, inUse }`, the currencies in use) and changes nothing |
| PATCH | `/api/settings/currencies/:currency` | `UpdateUserCurrency` (`{ enabled?, main? }`) | `UserCurrency[]`. `main: true` makes that currency the main one, in place of the previous one. 400 for `enabled: false` with `main: true` in the same body. 409 when the stored state makes the change impossible: it would leave the main currency disabled, or the user without a main one (`main: false` on it) |
| DELETE | `/api/settings/currencies/:currency` | | 204; 409 for the main currency, or for one that a template item, month item or daily spend is in |
| GET | `/api/sessions` | | `SessionEntry[]` — the user's valid sessions, the current one first |
| DELETE | `/api/sessions/:id` | | 204 — ends that session; 400 for the current one, which ends by signing out |
| DELETE | `/api/sessions` | | 204 — ends every session but the current one |
| DELETE | `/api/sessions/current` | | 204 — ends the session making the request, once it is deleted; the mobile app signs out with it |

## Behaviour notes

- **Creating a month** copies every template item into the month (`source: "template"`, default) or every item of the closest earlier month (`source: "previous"`). Items copied from a `variable` template item get `needsReview: true`; template items without an amount are copied with `amount: null`. The month is worked out in the `mainCurrency` sent, or in the user's main currency when it is left out, and keeps it from then on; a user with no currency gets 409. `lockedRates` starts as `{}`.
- **Editing a month item's `amount`** clears `needsReview` unless the request explicitly sends `needsReview`.
- **Rates** are quoted against a month's main currency: `rates.BRL` is how many reais one unit of it is worth. `MonthDetail.rates` holds the live ones for that currency.
- **`lockedRates`** on a month freezes the rate of the currencies in it; any other follows the live rate. `PATCH { lockedRates }` replaces the whole map, so locking one more currency means sending the others again, and `{}` unlocks all.
- **`summary`** is in the month's main currency (`summary.main`):
  - `totals` has each currency's own income, expenses and net.
  - `conversions` has one entry per other currency with items or spends: its `net`, the `rate` in use, whether it is locked, and the net `converted` into the main currency (net ÷ rate, with no fee). A net below zero is converted too.
  - `net` is the main currency's own net plus every `converted`. It is `null`, and so is the allowance, while a currency with something left has no rate.
- **Daily spends** (`MonthDetail.spends`) are day-to-day spending, stored apart from the month items and never counted in `summary.totals`. One sent without a `currency` goes in the month's main currency. A spend in another currency counts against the allowance through `spendInMain()` (amount ÷ rate). The client sends the `day` (the open day it shows), so day boundaries follow the browser's timezone.
- **`activeDay`** on a month is the day open for daily spending; `null` means "today" (or the 1st for a future month). Closing a day is `PATCH { activeDay }` with `nextActiveDay()` from `@maimoni/shared`; 32 means every day was closed. `summary.allowance.amount` is `(net − spends before the open day) ÷ days from the open day to month end`, and `remaining` subtracts the open day's own spends.
- **`summary`** is computed with `summarizeMonth` from `@maimoni/shared`, using the month's locked rates and the live ones for the rest. The frontend recomputes it locally with the same function after optimistic edits.
