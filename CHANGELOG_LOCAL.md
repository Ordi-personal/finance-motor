# CHANGELOG_LOCAL.md - Modificações Locais (Finance Motor)

---

## 📅 2026-03-07 - Atualização para Sure v0.6.8

### Base atualizada
- **De:** maybe-finance/maybe @ d5dc36a (Mai 2024)
- **Para:** we-promise/sure @ v0.6.8 (28 Fev 2026)

### O que o Sure v0.6.8 traz (sem ação nossa)
- Novos providers: SnapTrade, Mercury, Coinbase, Indexa Capital
- Remove Flipper (feature flags agora via ENV + `config/auth.yml`)
- Adiciona CORS (`rack-cors`) para clientes mobile (Flutter)
- Suporte a Redis Sentinel
- SSO multi-provider com SAML, JIT melhorado
- MCP server endpoint para assistentes AI externos
- Muitas migrations novas (Jan/Fev 2026)
- Ruby 3.4.7 no upstream (nós mantemos 3.2.2 por ora)

### Modificações re-aplicadas neste upgrade
| Arquivo | Modificação |
|---------|-------------|
| `config/initializers/content_security_policy.rb` | Re-ativado CSP com `frame_ancestors` para fluxome.app |
| `config/application.rb` | `config.i18n.default_locale = :'pt-BR'` |
| `config/routes.rb` | Rota `/auth/sso` + `/api/v1/preferences` |
| `app/controllers/concerns/fluxo_integration.rb` | Concern de embedded mode (restaurado) |
| `app/controllers/application_controller.rb` | `include FluxoIntegration` |
| `app/controllers/auth/sso_controller.rb` | Endpoint SSO JWT (restaurado) |
| `app/controllers/api/v1/base_controller.rb` | `authenticate_fluxo_secret` (X-Fluxo-Secret header) |
| `app/controllers/api/v1/preferences_controller.rb` | GET/PATCH de preferências (restaurado) |
| `app/helpers/languages_helper.rb` | `timezone_options(current_timezone)` + `timezone_label_for` |
| `app/views/settings/preferences/show.html.erb` | Passa timezone atual ao `timezone_options` |
| `app/services/saas/initial_data_service.rb` | Provisioning atômico de Rules (restaurado) |
| `config/locales/` (pt-BR) | Traduções restauradas + novas (budgets, chats, components, etc.) |
| `.ruby-version` | Mantido em 3.2.2 (upstream usa 3.4.7) |
| `Dockerfile` | `ARG RUBY_VERSION=3.2.2` |
| `config/deploy.yml` | Configuração de deploy Kamal (restaurado) |

### Pendências pós-upgrade
- [ ] Ruby 3.2.2 → 3.4.7: upgrade necessário em janela separada (testar gems, Dockerfile)
- [ ] Traduzir providers novos (coinbase, mercury, snaptrade, indexa, pdf_import_mailer) quando/se forem usados
- [ ] Executar migrations em staging antes de produção
- [ ] Testar fluxo SSO end-to-end após deploy

Este arquivo documenta todas as modificações feitas ao código-fonte do Finance Motor (fork do Maybe Finance) para facilitar futuras atualizações e evitar conflitos de merge.

---

## 📅 2026-02-08 - Tradução PT-BR e I18n

### Arquivos Criados
| Arquivo | Descrição |
|---------|-----------|
| `config/locales/account_pt-BR.yml` | Traduções para tipos e subtipos de contas |

### Arquivos Modificados

#### `app/models/concerns/accountable.rb`
- **Linha ~56**: Alterado `display_name` para usar `I18n.t`
- **Antes:** `self.name.pluralize.titleize`
- **Depois:** `I18n.t("account.types.#{self.name.underscore}", default: self.name.pluralize.titleize)`

#### `app/models/depository.rb`
- **Linha ~14**: Alterado `display_name` para usar `I18n.t`
- **Antes:** `"Cash"`
- **Depois:** `I18n.t("account.types.depository", default: "Cash")`

#### `app/views/depositories/_form.html.erb`
- **Linha 5**: Alterado mapeamento de `SUBTYPES`
- **Antes:** `Depository::SUBTYPES.map { |k, v| [v[:long], k] }`
- **Depois:** `Depository::SUBTYPES.map { |k, v| [t("account.subtypes.depository.#{k}", default: v[:long]), k] }`

#### `app/views/investments/_form.html.erb`
- **Linha 5**: Mesmo padrão de alteração (I18n para subtypes)

#### `app/views/properties/_form.html.erb`
- **Linha 5**: Mesmo padrão de alteração (I18n para subtypes)

#### `app/views/properties/_overview_fields.html.erb`
- **Linha 10**: Mesmo padrão de alteração (I18n para subtypes)

---

## 🔧 Como Aplicar Após Atualização

```bash
# 1. Verificar se os arquivos conflitaram
git status

# 2. Se conflitou, restaurar nossas alterações
git checkout --ours config/locales/account_pt-BR.yml

# 3. Para os demais, fazer merge manual seguindo o padrão I18n acima
```

---

## 📋 Checklist Pós-Atualização

- [ ] Verificar se `config/locales/account_pt-BR.yml` está intacto
- [ ] Verificar se `Accountable#display_name` usa I18n
- [ ] Verificar se `Depository#display_name` usa I18n
- [ ] Verificar formulários (`_form.html.erb`) usam I18n para subtypes
- [ ] Testar criação de conta no onboarding
