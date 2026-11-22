# Decisions

Choices made while turning `Financeiro.xlsx` into an app. They were made without anyone to ask, so each one says why.

## How the spreadsheet maps to the app

| Spreadsheet | App |
| --- | --- |
| `Template` sheet | **Template** page (`template_items`) |
| Each month sheet (`Março`, `Abril`…) | A **month** (`months`) with its own copy of the items (`month_items`) |
| BRL table (Nome / BRL / Pago) | BRL expense items |
| EUR table (Nome / Valor / Pago) | EUR expense items |
| `Entrada` in Resultado BRL | BRL **income** item (`kind: income`) — a list, so salary + extras can be separate lines |
| `Saída` / `Líquido` | Computed: sum of expenses / income − expenses |
| `Entrada` in Resultado EUR (`Líquido BRL × (1 − Taxa Wise) ÷ Preço Euro`) | The BRL net, converted at the rate with no fee |
| `Preço Euro` (GOOGLEFINANCE) | **Live rate** from the backend; can be **locked** per month (`lockedRates`) |
| `Taxa Wise` | Not counted. The app doesn't record transfers or what they cost |
| Allowance (`Líquido EUR ÷ (EOMONTH(TODAY()) − TODAY() + 1)`) + BRL equivalent | **Daily allowance** hero on the month page |
| Values typed as formulas (`=11.99+2.99`) | Amount inputs accept arithmetic; the expression is stored alongside the value. Numbers can be typed pt-BR style: `1.250,99`, `1250,99` and `2.500` (a dot followed by exactly three digits is a thousands separator, since money never has three decimals), plus `1250.99`. `R$`/`€` are ignored. |

All the arithmetic lives in one place, `packages/shared/src/summary.ts`, used by both the backend and the frontend, so optimistic edits show the same numbers the server would. Its tests reproduce the October sheet to the cent.

## Template vs. month

- **Creating a month copies the template.** Changing the template later never rewrites existing months. That's the same as copying a sheet.
- **Fixed vs. variable.** Template items have a `variable` flag ("muda todo mês"). Variable items are copied with their estimate (or empty) and marked `needsReview` in the new month, so the UI shows what still needs a real value. Typing an amount, or explicitly confirming it, clears the flag. Empty amounts (`null`) are "preencher" and count as 0.
- **Copy from the previous month** is offered as an alternative source. It copies amounts and resets `paid`; items linked to variable template items are flagged again.
- **"Salvar no template"** on a month item writes its name/value into the template, updating the linked item or creating a new linked one. This replaces editing the Template sheet after noticing a value changed for good.

## Currency and rate

- **Only BRL and EUR** (Postgres enum), matching the sheet.
- **A month is worked out in one currency, its main one.** It is the user's main currency when the month is created, stored on the month, so changing the main currency later leaves the months that exist as they were. The months that existed before this are in EUR.
- **Rates are quoted against the month's main currency:** how many units of each other currency one unit of it is worth. With EUR as the main one that is reais per euro, as `Preço Euro` was.
- **Live rate sources, in order:** Frankfurter (the ECB's reference rate, published once per working day), then open.er-api (updated once a day). No API keys needed, and nothing is asked of Wise. The rate is a daily reference, so it differs a little from what a transfer gets at the moment it is made. The providers are asked once a day for each base currency in use: the first request of a day (UTC) fetches the rates and stores them in `exchange_rates`, one row per quoted currency, and every other request that day reads those rows. If every provider fails, the last stored rates are served with `stale: true`, and the UI shows a badge.
- **Lock per month, per currency.** While a currency's rate is unlocked in a month it follows the live rate, as the spreadsheet did. Locking freezes it, so past months stop moving. The locked rates are a map on the month (`locked_rates`). Imported months are left unlocked because the workbook only had the GOOGLEFINANCE fallback value, which was the same in every sheet.
- **The conversion is a projection, with no fee.** What is left in each other currency is converted into the main one at the rate, in full. Transfers that were actually made, and what they cost, aren't recorded.
- **A net below zero is converted too.** A currency with more expenses than income has to be covered from the main one, so its deficit comes out of the month's net. Before the main currency existed, a negative BRL net was left out of the EUR result.

## Allowance

- **Current month:** the month's net, in its main currency, ÷ remaining days including today, like the sheet.
- **Future months:** divided by every day of the month.
- **Past months:** no allowance; the page shows "mês encerrado" with the final net instead. The sheet's `TODAY()` made old sheets show meaningless numbers.
- **Equivalents in the other currencies:** allowance × rate, with no fee, matching the sheet's BRL equivalent.

### Daily spending ("Hoje")

- **Kept apart from the month's obligations.** Day-to-day spends live in their own table (`daily_spends`). They never appear in the month's lists or in its totals. They only feed the allowance.
- **Any of the user's currencies.** A spend keeps its own currency and amount. One in a currency other than the month's main one costs the allowance what it would have become at the rate: amount ÷ rate, using the month's rate for that currency (locked or live). It isn't stored converted, so it follows the rate until that rate is locked. Without a rate, such spends count as zero until one is available.
- **An open day instead of the calendar day.** Each month has an `activeDay`: the day spends are recorded on. Until a day is first closed it's simply today (the 1st for a future month), so the numbers match the sheet's formula.
- **The formula:** day budget = (net − spends on days before the open day) ÷ days from the open day to the end of the month. What's left today = day budget − spends on the open day. A spend only reduces today; it doesn't change the budget until the day is closed.
- **"Fechar o dia"** moves the open day forward, and the same formula spreads the leftover (or the overspend) over the remaining days. Nothing extra is stored, so editing or deleting an old spend re-spreads automatically.
  - **Where it moves:** to today when earlier days were left open, or to tomorrow when today is the open day (closing at night). Past the last day, the month shows as fully closed.
  - **Undo:** the toast after closing offers "Desfazer", which restores the previous open day.
- **Days that aren't closed** keep their budget even after the calendar moves on, and new spends still go to that open day. A banner asks you to close it.

### Closed days calendar ("Dias fechados")

- **A calendar instead of a list.** Each day shows its result (budget − spent) in green or red, with a bar that fills from the left with what was left over (full when nothing was spent) or from the right with what went over (full at a whole day's budget over). Clicking a day shows its numbers and its spends, which can still be edited.
- **Past budgets are rebuilt, not stored.** `dayResults()` replays the month as if each day had been closed in order: a closed day's budget is (EUR net − spends on earlier days) ÷ days from it to the end of the month. The open day uses the same figures as Hoje, and upcoming days show what they'd get if the open day closed now. They use today's rate and fee, so they move with the month's numbers until its rate is locked.
- **The month total compares against the original plan.** "Sobrou/passou" is (closed days × net ÷ days in month) − what was spent on them. Adding up the daily results would double count, because what's left on one day rolls into the next days' budgets.
- **Weeks start on Monday**, as in Spain.
- **Months without daily spends** (before tracking existed) show an empty state instead of a calendar of meaningless all-green days.
- **The client decides what "today" is** and sends the day with each spend, so midnight follows your browser's timezone, not the server's (UTC in Docker).

## Initial data

- **The spreadsheet was imported once,** with a one-off script that has since been removed; the starting data now lives in a database dump instead.
- **Months were dated 2026**, since the workbook had no year. There was no `Maio` sheet, so May is absent.
- **Variable flags were inferred:** a template item became variable when its template value was empty or differed between month sheets (Nubank, BTG, Plano de Saúde in BRL, Mãe, Energia, Internet, Entrada).

## Stack & structure

- **Layout:** Bun workspaces with `apps/frontend`, `apps/backend` and `packages/shared` (Zod 4 schemas, API types, calculations). The shared package is consumed as TypeScript source; no build step.
- **Backend:** Hono on `Bun.serve`, Drizzle ORM with the `bun-sql` driver (Bun's native Postgres client, no `pg`/`postgres.js`), validation with `@hono/zod-validator`.
- **Money and rate columns:**
  - Money is `numeric(14,2)`, rates `numeric(12,6)`, fees `numeric(6,5)`, all read as JS numbers through Drizzle's numeric `mode: 'number'`.
  - Values are rounded to cents at the edges. Personal-budget sums are well within double precision.
- **Frontend:** Nuxt 4 as a client-rendered SPA (`ssr: false`; Vite's dev SSR failed to load zod from the shared package under Bun), Nuxt UI 4, with your `main.css` and `app.config.ts` verbatim. The browser only talks to Nuxt; a Nitro catch-all (`server/api/[...path].ts`) proxies `/api/**` to `NUXT_API_BASE`, so there's no CORS and the backend doesn't need to be public.
- **Auth:** Better Auth in the backend (`apps/backend/src/auth.ts`), mounted at `/api/auth`. Pages still send `noindex`.
  - Sign in with email and password, Google, Apple or a passkey. Google and Apple are enabled only when their credentials are set.
  - Sign up is disabled everywhere unless `AUTH_SIGNUP_ENABLED` is `true`, which opens it for email, Google and Apple with no allowlist. With it off, users are inserted by hand, with `email_verified` set so Google and Apple sign in link to the user with the same email. Store the email in lowercase, since Better Auth looks it up that way:

    ```sql
    INSERT INTO "user" (name, email, email_verified) VALUES ('Name', 'me@example.com', true);
    ```

  - Password reset: `POST /api/password-reset` always answers 204, so it can't be used to find out which emails have an account. It wraps Better Auth's `request-password-reset`, which answers 200 with a body. The email is sent through Resend's HTTP API (`apps/backend/src/services/mail.ts`) after the response: the endpoint answers before Better Auth looks the email up, so the response takes the same time either way. Resetting a password signs out every session of that user.
  - The web app uses the session cookie through the Nuxt proxy. The mobile app sends `Authorization: Bearer <token>` (Better Auth's `bearer` plugin; the token comes in the `set-auth-token` header of the sign in response).
  - Each sign in is an independent session:
    - Signing out on the web doesn't sign out the mobile app, and the other way around.
    - A password reset ends all of them.
    - `GET /api/sessions` lists them and `DELETE /api/sessions/:id` ends one from any other. They stand in for Better Auth's `list-sessions` and `revoke-session`, which only answer a session less than a day old and send every session's token to the client.
  - The mobile app's session:
    - The token is kept in the platform's secure storage.
    - On start the app checks it with `GET /api/auth/get-session`, which answers `null` for a token the server no longer accepts.
    - A 401 from a data route ends the session and shows the login screen.
    - Signing out ends the session on the device at once and keeps the token in secure storage until the server confirms it ended the session. A sign out made offline is sent again when the app next starts.
  - The mobile app signs in to Google and Apple with the platform SDKs and posts the provider's ID token to `/api/auth/sign-in/social`.
    - `GOOGLE_IOS_CLIENT_ID` adds the iOS OAuth client as an accepted audience of Google ID tokens, next to the web client.
    - `APPLE_APP_BUNDLE_IDENTIFIER` is the audience of Apple identity tokens from the app.
  - The mobile app signs in with passkeys through the system's passkey sheet:
    - Android assertions carry `android:apk-key-hash:<hash>` as their origin, so the passkey plugin's `origin` lists one per fingerprint in `ANDROID_APP_CERT_SHA256`, next to the web origin.
    - The challenge travels in a cookie. The verify request is the only one where the app sends a cookie, together with an `Origin` header, since Better Auth refuses a cookie without one.
    - The backend builds the association files (`assetlinks.json`, `apple-app-site-association`) and the frontend serves them at `/.well-known/*`.
  - Data is per user. Every user-owned table has its own `user_id`, so row-level security can check it without joins. Month items and spends reference their month through `(month_id, user_id)`, so their owner can't differ from the month's. Cached exchange rates stay shared.
  - The `0005_auth` migration assigns data that already exists to a placeholder owner (`owner@maimoni.invalid`). To keep that data, update the placeholder instead of inserting a new user:

    ```sql
    UPDATE "user" SET name = 'Name', email = 'me@example.com', email_verified = true
    WHERE id = '00000000-0000-4000-8000-000000000001';
    ```
- **UI language:** pt-BR, keeping the sheet's vocabulary (Entrada, Saída, Líquido, Pago). Money is formatted with `Intl.NumberFormat('pt-BR')`.
- **TypeScript is pinned to `^5.9`.** npm `latest` is TS 7 (the native port), which Vue tooling may not support yet. Bun runs TS directly anyway.
- **Migrations:**
  - Generated with `drizzle-kit generate` (`drizzle/0000_init.sql`).
  - In Docker, the backend applies them on start (`MIGRATE_ON_START=true` in compose).
  - Locally, run `mise run db:migrate` yourself; dev never migrates implicitly.
- **Docker:** both images build from the repo root (they need the workspace lockfile and `packages/shared`). Postgres 18 data lives in the `postgres` named volume.

## Testing

- **Shared:** calculation and expression tests, including the October sheet as a fixture.
- **Backend:** API tests run the real Hono app against **PGlite** (in-memory Postgres in the test process) with the real migrations, so they need no Docker and never touch a real database.
