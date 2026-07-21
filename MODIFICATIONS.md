# Modifications to Sure Finance Motor

This is a fork of [Sure](https://github.com/maybe-finance/maybe) (formerly Maybe Finance), licensed under **AGPL-3.0**.

## Legal Compliance

This fork complies with AGPL-3.0 Section 13 by:

- Making all modified source code publicly available in this repository
- Documenting all modifications in this file
- Maintaining the original AGPL-3.0 license unchanged
- Providing proper attribution to the original project

## Original Project

| Field | Value |
|-------|-------|
| **Name** | Sure (formerly Maybe Finance) |
| **Repository** | https://github.com/we-promise/sure |
| **License** | AGPL-3.0 |
| **Base Version** | Tag v0.7.1-alpha.11 (May 2026) |

## Fork Information

| Field | Value |
|-------|-------|
| **Fork Repository** | https://github.com/Ordi-personal/finance-motor |
| **Maintained By** | Ordi Team |
| **Fork Date** | May 2024 |
| **Last Upstream Sync** | May 25, 2026 (v0.7.1-alpha.11) |

## Modifications Made

### 1. Content Security Policy (CSP)

**File:** `config/initializers/content_security_policy.rb`
**Type:** Configuration
**Risk:** Low

Allow embedding the application in an iframe from configured origins via `FRAME_ANCESTORS_HOSTS` environment variable (no domains hardcoded in source code).

```diff
- policy.frame_ancestors :self
+ frame_hosts = ENV["FRAME_ANCESTORS_HOSTS"]&.split(",")&.map(&:strip)
+ if frame_hosts.present?
+   policy.frame_ancestors :self, *frame_hosts
+ else
+   policy.frame_ancestors :self, "http://localhost:3000"
+ end
```

### 2. Default Locale (pt-BR)

**File:** `config/application.rb`
**Type:** Configuration
**Risk:** Low

Set the default locale to Brazilian Portuguese.

```diff
+ config.i18n.default_locale = :'pt-BR'
```

### 3. Internationalization (pt-BR)

**Files:** `config/locales/pt-BR/*.yml` (multiple files)
**Type:** Translation
**Risk:** Low

Added Brazilian Portuguese translations for the entire application UI.

### 4. Preferences API Endpoint

**Files:**
- `app/controllers/api/v1/preferences_controller.rb` (new)
- `config/routes.rb` (modified)

**Type:** API Enhancement
**Risk:** Low-Medium

Added REST endpoint to synchronize user preferences (timezone, locale, currency) via API.

- `GET /api/v1/preferences` - Read current preferences
- `PATCH /api/v1/preferences` - Update preferences

### 5. Timezone Helper Enhancement

**File:** `app/helpers/languages_helper.rb`
**Type:** Bug Fix
**Risk:** Low

Added fallback support for TZInfo timezone identifiers not mapped in `ActiveSupport::TimeZone`, preventing incorrect timezone display in the dropdown.

### 6. SSO User Provisioning Fix

**File:** `app/services/saas/initial_data_service.rb`
**Type:** Bug Fix
**Risk:** Low-Medium

Fixed atomic creation of Rules with nested Actions to comply with upstream validation changes requiring at least one action per rule.

### 7. Timezone View Fix

**File:** `app/views/settings/preferences/show.html.erb`
**Type:** Bug Fix
**Risk:** Low

Pass current timezone to `timezone_options` helper to ensure the selected timezone appears in the dropdown list.

### 8. SSO Controller (JWT-based iframe login)

**Files:**
- `app/controllers/auth/sso_controller.rb` (new)
- `config/routes.rb` (modified)

**Type:** New Feature
**Risk:** Medium

Single sign-on endpoint allowing the Ordi App to authenticate users into the embedded iframe via a short-lived JWT token. The token is signed with the secret in `ENV["SSO_SECRET_KEY"]` (a dedicated shared secret managed via deploy config, **not** derived from `RAILS_MASTER_KEY`), validated on arrival (issuer/audience/expiry/replay checks), and exchanged for a Rails session.

- `GET /auth/sso?token=<jwt>` — Validates JWT and logs the user in

### 9. Embedded Mode (`OrdiIntegration` concern)

**Files:**
- `app/controllers/concerns/ordi_integration.rb` (new)
- `app/controllers/application_controller.rb` (modified)

**Type:** Integration
**Risk:** Low

Extracted embedded-mode logic into a Rails concern so that all controllers can detect whether the app is running inside the Ordi iframe (`session[:embedded_mode]`). Uses `helper_method :embedded_mode?` to expose the state to views. This remains a fork-only integration layer across upstream syncs.

### 10. Server-to-Server Auth (`X-Ordi-Secret`)

**File:** `app/controllers/api/v1/base_controller.rb` (modified)

**Type:** Security / Integration
**Risk:** Medium

Added a minimal bypass in the API base controller that allows the Ordi App to authenticate server-to-server requests without a user JWT. The bypass requires:

1. `X-Ordi-Secret` header matching `ENV["ORDI_SHARED_SECRET"]` (via `ActiveSupport::SecurityUtils.secure_compare`)
2. `X-User-Email` header identifying the target user

The secret is managed via deploy secrets and is never hardcoded. If `ORDI_SHARED_SECRET` is not set, the bypass is fully disabled. The bypass is also limited to a small allowlist of internal API paths.

### 11. Ruby Version Pin (3.4.2)

**Files:**
- `.ruby-version`
- `Dockerfile`

**Type:** Configuration
**Risk:** Low

Upstream `v0.7.1-alpha.11` targets Ruby `3.4.7`. This fork currently pins the runtime to `3.4.2` for compatibility with the current production environment. A separate Ruby upgrade is planned.

### 12. Local Credentials Pair Preserved Across Upstream Syncs

**Files:**
- `config/credentials.yml.enc`
- `config/master.key`

**Type:** Operational safeguard
**Risk:** Medium

The fork keeps its own encrypted credentials pair. After an upstream base replacement, the local `config/credentials.yml.enc` and `config/master.key` must remain aligned; otherwise Rails boot fails during credentials decryption.

### 13. Embedded Mode: Hide Logo and Chat Sidebar

**File:** `app/views/layouts/application.html.erb` (modified)

**Type:** Integration
**Risk:** Low

When running inside the Ordi iframe (`embedded_mode?`), the main application layout now:
- Hides the Sure logo (replaced with empty space) in both mobile and desktop nav
- Hides the entire right sidebar (AI chat / "Enable AI Chats")
- Hides the panel-right toggle button
- Removes the "Assistente" item from mobile bottom nav

### 14. Onboarding Completeness Fixes

**Files:**
- `app/controllers/onboardings_controller.rb` (modified)
- `app/views/onboardings/goals.html.erb` (modified)
- `app/views/onboardings/show.html.erb` (modified)
- `app/views/layouts/wizard.html.erb` (modified)
- `config/locales/views/onboardings/en.yml` (modified)
- `config/locales/views/onboardings/pt-BR.yml` (modified)

**Type:** Bug Fix / i18n
**Risk:** Low

- Added missing `goals` action to `OnboardingsController` (route existed but action was absent).
- Fixed `show.html.erb` to pass `product_name:` interpolation variable to `t(".title")`.
- Changed goals form from `form_with` to `styled_form_with` with Turbo disabled, matching other onboarding steps.
- Completed English and pt-BR translations for all onboarding steps (goals, header nav items, placeholders, field labels).
- Modified wizard layout to hide logo and sign-out button when in embedded mode (`embedded_mode?`).

### 15. SSO Onboarding Auto-Complete

**File:** `app/controllers/auth/sso_controller.rb` (modified)

**Type:** Enhancement
**Risk:** Low-Medium

SSO callback now ensures existing users have `onboarded_at` set (skipping onboarding) and syncs profile data (first_name, last_name, locale, currency, country) from the JWT payload. New users also receive profile data from the JWT instead of email-derived defaults.

### 16. Accounts API: `POST /api/v1/accounts`

**Files:**
- `app/controllers/api/v1/accounts_controller.rb` (modified — new `create` action + scoped before_actions; `index`/`show` untouched)
- `app/views/api/v1/accounts/_account.json.jbuilder` (modified — 1 line added)
- `config/routes.rb` (modified — 1 line added to the existing `resources :accounts` entry)
- `spec/requests/api/v1/accounts_spec.rb`, `spec/swagger_helper.rb` (modified — OpenAPI docs for the new endpoint + `available_credit` field)
- `test/controllers/api/v1/accounts_controller_test.rb` (modified — new tests appended)

**Type:** API Enhancement
**Risk:** Low-Medium

Adds account creation to the existing read-only Accounts API so the Ordi App no longer has to write directly into Sure's Postgres database to create accounts. Reuses `Account.create_and_sync` (the same path the web `AccountableResource` controllers use), so opening-balance anchors, `owner` assignment, and post-create sync all follow upstream's own creation semantics — no account-creation business logic was reimplemented. Requires the `write` scope (`read_write` API key scope, or the `X-Ordi-Secret` S2S bypass, which is already granted full read/write scopes). Accepts `name`, `balance`, `currency`, `subtype` (defaults to the accountable type's own default, e.g. `checking` for Depository), and `accountable_type` (defaults to `Depository`; validated against `Accountable::TYPES`).

- `POST /api/v1/accounts` — `{ "account": { "name": "...", "balance": 100, "currency": "BRL" } }` → `201` with the same JSON shape as `GET /api/v1/accounts/:id`, or `422` on validation failure.

### 17. `available_credit` on Account Serialization

**File:** `app/views/api/v1/accounts/_account.json.jbuilder` (modified — 1 line added; shared with item 16 above)

**Type:** API Enhancement
**Risk:** Low

Exposes `account.accountable.available_credit` as `available_credit` in the account JSON payload when the account's accountable is a `CreditCard`. Omitted entirely for all other account types.

### 18. Provisioning API: `POST /api/v1/provisioning`

**Files:**
- `app/controllers/api/v1/provisioning_controller.rb` (new)
- `app/services/saas/user_provisioning_service.rb` (new)
- `config/routes.rb` (modified — 1 line added)
- `app/controllers/api/v1/base_controller.rb` (modified — 1 line added to `ORDI_ALLOWED_PATHS`)
- `test/controllers/api/v1/provisioning_controller_test.rb` (new)

**Type:** New Feature
**Risk:** Medium

Internal server-to-server endpoint that lets the Ordi App provision a fully-onboarded Sure user (Family + User + default pt-BR categories/rules via `Saas::InitialDataService` + trial subscription + optional initial account) in one call, instead of writing Family/User/Subscription rows directly into Sure's database. `Saas::UserProvisioningService` mirrors `Auth::SsoController#create_sso_user`'s Family/User/bootstrap/`start_trial_subscription!` sequence exactly (extracted into its own additive service rather than modifying the SSO controller) so a provisioned user is indistinguishable from one created via the SSO callback.

Authentication is intentionally narrower than the rest of the API: only the `X-Ordi-Secret` shared secret is accepted (OAuth and `X-Api-Key` are rejected), since this endpoint can create user accounts. It does **not** reuse `BaseController#authenticate_ordi_secret` because that method requires an *existing* user (it looks one up by `X-User-Email` and fails otherwise) — provisioning must work for brand-new emails too. Idempotent: a second call for an already-provisioned email returns the existing user/family (`created: false`, `HTTP 200`) instead of erroring.

- `POST /api/v1/provisioning` — `{ "email": "...", "first_name": "...", "last_name": "...", "time_zone": "...", "currency": "...", "locale": "...", "initial_account": { "name": "Dinheiro", "balance": 0, "currency": "BRL", "subtype": "cash" } }` → `201` (new) or `200` (idempotent replay) with `{ "created": bool, "user": {...}, "family": {...}, "account": {...} | null }`. `initial_account.subtype` is optional (defaults to `checking`); Ordi passes `cash` for its default "Dinheiro" account to match historical provisioning.

**Known limitation:** like `Auth::SsoController#create_sso_user`, `Saas::InitialDataService.bootstrap!` unconditionally overwrites the family's `currency`/`locale`/`country`/`date_format` to `BRL`/`pt-BR`/`BR`/`%d/%m/%Y` regardless of what was passed in. This is pre-existing upstream-fork behavior (see item 6), not something introduced or changed here.

## What Is NOT Modified

- Core financial calculation engine
- Authentication/authorization logic (upstream flows unchanged)
- Original API endpoints behavior
- Any business logic or accounting rules

## Architecture

This fork runs as an **isolated service** communicating with other applications exclusively via HTTP REST API and iframe embedding. There is no code linking or shared process space with any other application.

## Contributing

Contributions to this fork are welcome. Note that:

- All contributions will be under AGPL-3.0
- Useful changes may be submitted upstream as Pull Requests
- Upstream contributions are preferred when applicable

## License

### 19. Transfers API: `POST /api/v1/transfers`

**Files:**
- `app/controllers/api/v1/transfers_controller.rb` (modified — new `create` action + scoped before_actions; `index`/`show` untouched)
- `config/routes.rb` (modified — `:create` added to the existing `resources :transfers` entry)
- `spec/requests/api/v1/transfers_spec.rb` (modified — OpenAPI docs for the new endpoint)
- `test/controllers/api/v1/transfers_controller_test.rb` (modified — new tests appended)

**Type:** API Enhancement
**Risk:** Low-Medium

Adds transfer creation to the existing read-only Transfers API so the Ordi App's "create_transfer" assistant tool works over HTTP (it previously called a nonexistent endpoint). Reuses `Transfer::Creator` — the exact same path the web `TransfersController#create` uses — so account lookup scoping (family-only), transaction pairing, status and post-create account syncs all follow upstream's own creation semantics; no transfer business logic was reimplemented. Requires the `write` scope (`read_write` API key, or the `X-Ordi-Secret` S2S bypass). Payload mirrors the web form: `{ "transfer": { "from_account_id", "to_account_id", "amount", "date" (optional, defaults to today), "exchange_rate" (optional) } }` → `201` with the same JSON shape as `GET /api/v1/transfers/:id`, `422` on validation failure, `404` when either account is outside the caller's family.

### 20. S2S Allowlist Correction (`ORDI_ALLOWED_PATHS`)

**File:** `app/controllers/api/v1/base_controller.rb` (modified — allowlist introduced in item 10)

**Type:** Bug Fix
**Risk:** Low

Two corrections to the internal allowlist used by the `X-Ordi-Secret` bypass:
- Added `/api/v1/categories`: the Ordi App resolves category names to ids via `GET /api/v1/categories` before creating transactions; without the entry the request was rejected (401) and every transaction was silently created without a category.
- Removed `/api/v1/insights`: that route has never existed in this codebase (nor upstream) — the entry only masked broken callers on the Ordi App side, which have now been cleaned up.

This fork maintains the original **AGPL-3.0** license. See [LICENSE](LICENSE) file.

---

**Last Updated:** July 2026
