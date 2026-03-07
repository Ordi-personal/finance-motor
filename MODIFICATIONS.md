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
| **Repository** | https://github.com/maybe-finance/maybe |
| **License** | AGPL-3.0 |
| **Base Version** | Tag v0.6.8 (February 28, 2026) |

## Fork Information

| Field | Value |
|-------|-------|
| **Fork Repository** | https://github.com/Ordi-personal/finance-motor |
| **Maintained By** | Ordi / Fluxo Team |
| **Fork Date** | May 2024 |
| **Last Upstream Sync** | March 7, 2026 (v0.6.8) |

## Modifications Made

### 1. Content Security Policy (CSP)

**File:** `config/initializers/content_security_policy.rb`
**Type:** Configuration
**Risk:** Low

Allow embedding the application in an iframe from the Fluxo App domain.

```diff
- policy.frame_ancestors :self
+ policy.frame_ancestors :self, "http://localhost:3000", "https://fluxome.app", "https://*.fluxome.app"
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

Single sign-on endpoint allowing the Fluxo App to authenticate users into the embedded iframe via a short-lived JWT token. The token is signed with `RAILS_MASTER_KEY`-derived secret, validated on arrival, and exchanged for a Rails session.

- `GET /auth/sso?token=<jwt>` — Validates JWT and logs the user in

### 9. Fluxo Embedded Mode (FluxoIntegration concern)

**Files:**
- `app/controllers/concerns/fluxo_integration.rb` (new)
- `app/controllers/application_controller.rb` (modified)

**Type:** Integration
**Risk:** Low

Extracted embedded-mode logic into a Rails concern so that all controllers can detect whether the app is running inside the Fluxo iframe (`session[:embedded_mode]`). Uses `helper_method :embedded_mode?` to expose the state to views. This replaced a previous `Current.embedded` attribute that was removed in upstream `v0.6.8`.

### 10. Fluxo Secret Server-to-Server Auth

**File:** `app/controllers/api/v1/base_controller.rb` (modified)

**Type:** Security / Integration
**Risk:** Medium

Added a minimal bypass in the API base controller that allows the Fluxo App to authenticate server-to-server requests without a user JWT. The bypass requires:

1. `X-Fluxo-Secret` header matching `ENV["FLUXO_SHARED_SECRET"]` (via `ActiveSupport::SecurityUtils.secure_compare`)
2. `X-User-Email` header identifying the target user

The secret is managed via Kamal secrets (`config/deploy.yml` → `env.secret`) and is never hardcoded. If `FLUXO_SHARED_SECRET` is not set, the bypass is fully disabled.

### 11. Ruby Version Pin (3.2.2)

**Files:**
- `.ruby-version`
- `Dockerfile`

**Type:** Configuration
**Risk:** Low

Upstream `v0.6.8` targets Ruby `3.4.7`. This fork pins the runtime to `3.2.2` for compatibility with the current production environment. A separate Ruby upgrade is planned.

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

This fork maintains the original **AGPL-3.0** license. See [LICENSE](LICENSE) file.

---

**Last Updated:** March 2026
