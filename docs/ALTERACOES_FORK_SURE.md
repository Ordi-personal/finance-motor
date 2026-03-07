# Alteracoes Minimas no Sure (fork)

Este documento descreve as alteracoes minimas feitas no finance-motor para o fork do Sure, com foco em sincronizacao de preferencias e localizacao.

## Objetivo

- Permitir que o Fluxo App sincronize preferencias (especialmente fuso horario) via API.
- Definir o idioma padrao do Sure para pt-BR.
- Garantir que o dropdown de timezone mostre corretamente o timezone atual, mesmo para TZInfo identifiers nao mapeados no ActiveSupport::TimeZone.

## Alteracoes aplicadas

### 1) Endpoint de preferencias na API

- Arquivo: `finance-motor/app/controllers/api/v1/preferences_controller.rb`
- O que faz:
  - GET /api/v1/preferences: retorna preferencias atuais da familia.
  - PATCH /api/v1/preferences: atualiza locale, currency, country, date_format, timezone.
- Autorizacao:
  - Usa `ensure_read_scope` (show) e `ensure_write_scope` (update).
  - Metodos adicionados: `ensure_read_scope` e `ensure_write_scope` chamando `authorize_scope!(:read/:write)`.
- Observabilidade:
  - Logs informativos com payload e resultado.

### 2) Rota da API para preferencias

- Arquivo: `finance-motor/config/routes.rb`
- Alteracao:
  - Adiciona `resource :preferences` dentro de `/api/v1`.

### 3) Locale padrao pt-BR

- Arquivo: `finance-motor/config/application.rb`
- Alteracao:
  - `config.i18n.default_locale = :'pt-BR'`

### 4) Helper de timezone com suporte a TZInfo identifiers

- Arquivo: `finance-motor/app/helpers/languages_helper.rb`
- Alteracao:
  - Metodo `timezone_options(current_timezone = nil)` agora aceita o timezone atual como parametro.
  - Se o timezone atual nao estiver na lista do `ActiveSupport::TimeZone.all`, adiciona-o dinamicamente usando `TZInfo::Timezone.get`.
  - Novo metodo auxiliar: `timezone_label_for(timezone_identifier)` para formatar o label com offset e nome.

### 5) View de preferencias com timezone correto

- Arquivo: `finance-motor/app/views/settings/preferences/show.html.erb`
- Alteracao:
  - Chama `timezone_options(family_form.object.timezone)` para garantir que o timezone atual esteja na lista de opcoes.

## Risco e impacto

- **Endpoint de preferencias:**
  - Risco baixo a moderado, pois expande a API.
  - Mitigacao: scopes de leitura/escrita e logs.
- **Locale padrao:**
  - Risco baixo, muda idioma e pode afetar formatos de data/moeda.
- **Helper de timezone:**
  - Risco baixo, adiciona fallback para timezones nao mapeados no ActiveSupport::TimeZone.
  - Beneficio: evita que o dropdown mostre timezone incorreto (ex: GMT-12 em vez de America/Campo_Grande).

## Relacao com o Fluxo App

- O Fluxo App chama PATCH `/api/v1/preferences` via `SureApiService`.
- Essa rota e necessaria para sincronizar o fuso horario (timezone) de forma confiavel.
- As alteracoes no helper garantem que o timezone selecionado no Fluxo App seja exibido corretamente no Sure.

## Observacoes

- Nao ha alteracoes de modelo ou banco no Sure (a coluna `families.timezone` ja existia).
- As mudancas sao isoladas e podem ser revertidas se necessario.
- Todas as alteracoes estao documentadas neste arquivo para facilitar o upgrade estrategico (ver `docs/agpl3/upgrade_strategy.md`).
