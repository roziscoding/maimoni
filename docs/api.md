# API

Base path: `/api`. JSON in, JSON out. All types live in `@maimoni/shared` (`packages/shared/src`).
Validation errors return `400 { error, issues }`; missing resources `404 { error }`; conflicts `409 { error }`.

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
| GET | `/api/rates/live` | | `LiveRate` (503 when no provider answered and nothing is cached) |
| GET | `/api/wise/quote?sendAmount=` or `?recipientGetsAmount=` | | `WiseQuote` — fills the other side and fee from Wise (503 when Wise can't be reached) |
| GET | `/api/template` | | `TemplateDetail` (`{ items, settings }`) |
| POST | `/api/template/items` | `CreateTemplateItem` | `TemplateItem` (201) |
| PATCH | `/api/template/items/:id` | `UpdateTemplateItem` | `TemplateItem` |
| DELETE | `/api/template/items/:id` | | 204 |
| PUT | `/api/template/items/order` | `{ ids: string[] }` | `TemplateItem[]` |
| PATCH | `/api/settings` | `UpdateSettings` | `Settings` |
| GET | `/api/months` | | `MonthListEntry[]` (newest first) |
| POST | `/api/months` | `CreateMonth` (`{ year, month, source? }`) | `MonthDetail` (201, 409 if it exists) |
| GET | `/api/months/:year/:month` | | `MonthDetail` |
| PATCH | `/api/months/:year/:month` | `UpdateMonth` | `MonthDetail` |
| DELETE | `/api/months/:year/:month` | | 204 |
| POST | `/api/months/:year/:month/items` | `CreateMonthItem` | `MonthItem` (201) |
| PATCH | `/api/months/:year/:month/items/:id` | `UpdateMonthItem` | `MonthItem` |
| DELETE | `/api/months/:year/:month/items/:id` | | 204 |
| PUT | `/api/months/:year/:month/items/order` | `{ ids: string[] }` | `MonthItem[]` |
| POST | `/api/months/:year/:month/items/:id/promote` | | `TemplateItem` — writes the item's name/amount/expression into the template (updates the linked template item or creates a new one and links it) |
| GET | `/api/months/:year/:month/conversions` | | `Conversion[]` |
| POST | `/api/months/:year/:month/conversions` | `CreateConversion` | `Conversion` (201) |
| PATCH | `/api/months/:year/:month/conversions/:id` | `UpdateConversion` | `Conversion` |
| DELETE | `/api/months/:year/:month/conversions/:id` | | 204 |
| POST | `/api/months/:year/:month/spends` | `CreateDailySpend` (`{ day, amount, currency?, expression?, note? }`) | `DailySpend` (201) |
| PATCH | `/api/months/:year/:month/spends/:id` | `UpdateDailySpend` | `DailySpend` |
| DELETE | `/api/months/:year/:month/spends/:id` | | 204 |
| DELETE | `/api/data` | | 204 — deletes the user's months (with their items, spends and conversions), template items and settings (settings come back with defaults on next read) |

## Behaviour notes

- **Creating a month** copies every template item into the month (`source: "template"`, default) or every item of the closest earlier month (`source: "previous"`). Items copied from a `variable` template item get `needsReview: true`; template items without an amount are copied with `amount: null`. `wiseFee` and `exchangeRate` start as `null`.
- **Editing a month item's `amount`** clears `needsReview` unless the request explicitly sends `needsReview`.
- **`exchangeRate: null`** on a month means "use the live rate". Locking = PATCH the month with the current live rate.
- **`wiseFee: null`** on a month means "use Wise's quote for the BRL still expected to be converted"; a number is a manual percentage. `MonthDetail.quote` carries the quote used, and `MonthDetail.fallbackFee` (the settings fee) applies when there is no quote. `summary.transfer.feeSource` says which one was used (`wise`, `manual` or `fallback`).
- **Conversions** (`MonthDetail.conversions`) record completed BRL→EUR transfers: day, total BRL sent including the fee, fee in BRL, EUR received, and an optional note. The summary separates their actual amounts under `summary.transfer.realized`, then projects only `summary.transfer.remainingBrl` under `summary.transfer.projected`.
- **Daily spends** (`MonthDetail.spends`) are day-to-day spending in `EUR` (default) or `BRL`, stored apart from the month items and never counted in `summary.eur`. BRL spends count against the allowance through `spendInEur()` (amount × (1 − fee) ÷ rate). The client sends the `day` (the open day it shows), so day boundaries follow the browser's timezone.
- **`activeDay`** on a month is the day open for daily spending; `null` means "today" (or the 1st for a future month). Closing a day is `PATCH { activeDay }` with `nextActiveDay()` from `@maimoni/shared`; 32 means every day was closed. `summary.allowance` is `(eur.net − spends before the open day) ÷ days from the open day to month end`, and `remainingEur` subtracts the open day's own spends.
- **`summary`** is computed with `summarizeMonth` from `@maimoni/shared`, using the month's locked rate or the live rate. The frontend recomputes it locally with the same function after optimistic edits.
