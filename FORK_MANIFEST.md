# Sure fork manifest

This file is the upgrade map for `finance-motor`. `MODIFICATIONS.md` is the
canonical detail for every divergence; this manifest is the compact inventory
used before and after an upstream sync.

## Base

| Field | Value |
|---|---|
| Upstream | `https://github.com/we-promise/sure` |
| Version | `.sure-version` = `0.7.1-alpha.11` |
| Upstream commit | Not published as a tag by upstream; the source tree was imported at local sync commit `c47aafa946a0c9d85624dcab29dd328049e4b911` |
| License | AGPL-3.0 (unchanged) |
| Detail source | [`MODIFICATIONS.md`](MODIFICATIONS.md) |

## Divergence inventory

Categories: `upstream-candidate` is suitable for upstream discussion;
`fork-integration` is required by the Ordi HTTP/iframe boundary;
`deploy-overlay` is environment or branding configuration; and
`app-side-candidate` should migrate to `fluxo-app` when the boundary permits.

| Ref | Files / area | Category | Status |
|---:|---|---|---|
| 1 | `config/initializers/content_security_policy.rb` | deploy-overlay | maintained |
| 2–3 | `config/application.rb`, `config/locales/pt-BR/*` | deploy-overlay | maintained |
| 4 | `app/controllers/api/v1/preferences_controller.rb`, routes | fork-integration | maintained; contract-tested |
| 5, 7 | `app/helpers/languages_helper.rb`, preferences view | upstream-candidate | maintained |
| 6 | `app/services/saas/initial_data_service.rb` | upstream-candidate | maintained; bootstrap contract required |
| 8, 15, 23 | `app/controllers/auth/sso_controller.rb`, SSO tests | fork-integration / upstream-candidate | maintained; security contract required |
| 9 | `app/controllers/concerns/ordi_integration.rb`, application controller | fork-integration | maintained |
| 10, 20 | `app/controllers/api/v1/base_controller.rb` and allowlist | fork-integration | maintained; security review required |
| 11 | `.ruby-version`, `Dockerfile` | deploy-overlay | maintained locally |
| 12 | `config/credentials.yml.enc`, `config/master.key` | deploy-overlay | maintained locally; never merge blindly |
| 13 | `app/views/layouts/application.html.erb` | deploy-overlay | maintained |
| 14 | onboarding controllers/views/layout/locales | deploy-overlay | maintained |
| 16–17 | accounts controller, account serializer, routes/specs/tests | fork-integration / upstream-candidate | maintained; contract-tested |
| 18, 25 | provisioning controller/service/tests | fork-integration / upstream-candidate | maintained; contract-tested |
| 19 | transfers controller/routes/specs/tests | fork-integration / upstream-candidate | maintained; contract-tested |
| 21 | transfer creator/serializer/specs/tests | fork-integration / upstream-candidate | maintained; contract-tested |
| 22 | transactions/transfers filters and API docs | fork-integration / upstream-candidate | maintained; contract-tested |
| 24 | transaction `kind` serializer | fork-integration / upstream-candidate | maintained; contract-tested |

## Upgrade checklist

1. Create an isolated branch/worktree and record the new upstream version and
   commit before changing files.
2. Import the upstream tree, then reapply only the manifest entries whose
   status is `maintained`; do not use `git checkout --ours`/`--theirs` in the
   hotspots listed below.
3. Run the Crivo contract suite against the real jbuilder payloads before and
   after the sync, including SSO replay, provisioning, account, transaction
   and transfer access/shape checks.
4. Run the focused provisioning, SSO and API tests, then `zeitwerk:check`,
   RuboCop and Brakeman in both services.
5. Review `git diff -- finance-motor/` and update both this manifest and
   `MODIFICATIONS.md` in the same commit. Keep `CHANGELOG_LOCAL.md` as a
   pointer only.

Hotspots requiring manual review: `app/controllers/auth/sso_controller.rb`,
`app/controllers/api/v1/base_controller.rb`,
`app/controllers/api/v1/provisioning_controller.rb`,
`app/services/saas/initial_data_service.rb`, API serializers, routes,
`config/credentials.yml.enc`, `config/deploy.example.yml`, CSP and embedded
layouts.
