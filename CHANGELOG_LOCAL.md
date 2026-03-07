# CHANGELOG_LOCAL.md - Modificações Locais (Finance Motor)

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
