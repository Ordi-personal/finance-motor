module Saas
  class InitialDataService
    def self.bootstrap!(family)
      new(family).bootstrap!
    end

    def initialize(family)
      @family = family
    end

    def bootstrap!
      ActiveRecord::Base.transaction do
        setup_family_defaults
        create_default_categories
        create_brazilian_rules
      end
    end

    private

    attr_reader :family

    def setup_family_defaults
      family.update!(
        currency: "BRL",
        locale: "pt-BR",
        country: "BR",
        date_format: "%d/%m/%Y"
      )
    end

    def create_default_categories
      # Ported logic from Category.default_categories but scoped to family
      default_categories_data.each do |name, color, icon, classification|
        family.categories.find_or_create_by!(name: name) do |category|
          category.color = color
          category.classification = classification
          category.lucide_icon = icon
        end
      end
    end

    def create_brazilian_rules
      rules_data.each do |name, keywords, category_name|
        category = family.categories.find_by(name: category_name)
        next unless category

        keywords.each do |keyword|
          rule_name = "Auto Categorizar: #{keyword}"
          
          next if family.rules.exists?(name: rule_name)

          family.rules.create!(
            name: rule_name,
            resource_type: "transaction",
            active: true,
            conditions_attributes: [
              {
                condition_type: "transaction_name",
                operator: "like",
                value: keyword
              }
            ],
            actions_attributes: [
              {
                action_type: "set_transaction_category",
                value: category.id
              }
            ]
          )
        end
      end
    end

    def default_categories_data
      [
        [ I18n.t("models.category.defaults.income", locale: :"pt-BR"), "#22c55e", "circle-dollar-sign", "income" ],
        [ I18n.t("models.category.defaults.food_drink", locale: :"pt-BR"), "#f97316", "utensils", "expense" ],
        [ I18n.t("models.category.defaults.groceries", locale: :"pt-BR"), "#407706", "shopping-bag", "expense" ],
        [ I18n.t("models.category.defaults.shopping", locale: :"pt-BR"), "#3b82f6", "shopping-cart", "expense" ],
        [ I18n.t("models.category.defaults.transportation", locale: :"pt-BR"), "#0ea5e9", "bus", "expense" ],
        [ I18n.t("models.category.defaults.travel", locale: :"pt-BR"), "#2563eb", "plane", "expense" ],
        [ I18n.t("models.category.defaults.entertainment", locale: :"pt-BR"), "#a855f7", "drama", "expense" ],
        [ I18n.t("models.category.defaults.healthcare", locale: :"pt-BR"), "#4da568", "pill", "expense" ],
        [ I18n.t("models.category.defaults.personal_care", locale: :"pt-BR"), "#14b8a6", "scissors", "expense" ],
        [ I18n.t("models.category.defaults.home_improvement", locale: :"pt-BR"), "#d97706", "hammer", "expense" ],
        [ I18n.t("models.category.defaults.mortgage_rent", locale: :"pt-BR"), "#b45309", "home", "expense" ],
        [ I18n.t("models.category.defaults.utilities", locale: :"pt-BR"), "#eab308", "lightbulb", "expense" ],
        [ I18n.t("models.category.defaults.subscriptions", locale: :"pt-BR"), "#6366f1", "wifi", "expense" ],
        [ I18n.t("models.category.defaults.insurance", locale: :"pt-BR"), "#0284c7", "shield", "expense" ],
        [ I18n.t("models.category.defaults.sports_fitness", locale: :"pt-BR"), "#10b981", "dumbbell", "expense" ],
        [ I18n.t("models.category.defaults.gifts_donations", locale: :"pt-BR"), "#61c9ea", "hand-helping", "expense" ],
        [ I18n.t("models.category.defaults.taxes", locale: :"pt-BR"), "#dc2626", "landmark", "expense" ],
        [ I18n.t("models.category.defaults.loan_payments", locale: :"pt-BR"), "#e11d48", "credit-card", "expense" ],
        [ I18n.t("models.category.defaults.services", locale: :"pt-BR"), "#7c3aed", "briefcase", "expense" ],
        [ I18n.t("models.category.defaults.fees", locale: :"pt-BR"), "#6b7280", "receipt", "expense" ],
        [ I18n.t("models.category.defaults.savings_investments", locale: :"pt-BR"), "#059669", "piggy-bank", "expense" ],
        [ I18n.t("models.category.defaults.investment_contributions", locale: :"pt-BR"), "#0d9488", "trending-up", "expense" ]
      ]
    end

    def rules_data
      # Scoped to PT-BR categories
      cat = lambda { |key| I18n.t("models.category.defaults.#{key}", locale: :"pt-BR") }
      
      [
        [ "Uber/99", ["Uber", "99Pop", "99*Pop", "Uber *Trip"], cat.call("transportation") ],
        [ "Posto Gasolina", ["Posto", "Ipiranga", "Shell", "Petrobras"], cat.call("transportation") ],
        [ "Pedágio", ["Sem Parar", "Conectcar", "Auto Expresso"], cat.call("transportation") ],
        [ "Delivery", ["iFood", "Rappi", "Uber Eats", "Zé Delivery"], cat.call("food_drink") ],
        [ "Mercado", ["Carrefour", "Pao de Acucar", "Assai", "Atacadao", "Extra", "Supermercado"], cat.call("groceries") ],
        [ "Padaria", ["Padaria", "Panificadora"], cat.call("food_drink") ],
        [ "Streaming", ["Netflix", "Spotify", "Amazon Prime", "Disney+", "HBO", "Apple.com/bill"], cat.call("subscriptions") ],
        [ "Cloud/Tech", ["AWS", "Amazon Web Services", "Heroku", "DigitalOcean", "Google Cloud"], cat.call("services") ],
        [ "Internet/TV", ["Claro", "Vivo", "Tim", "Oi", "Net Servicos"], cat.call("utilities") ],
        [ "Energy", ["Enel", "Light", "Cemig", "Copel", "CPFL"], cat.call("utilities") ]
      ]
    end
  end
end
