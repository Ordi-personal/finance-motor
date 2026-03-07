# frozen_string_literal: true

# Usage: bin/rails runner seed_rules.rb

def create_rule(family, name, merchant_matches, category_name)
  puts "Processing rule: #{name} -> #{category_name}..."
  
  category = family.categories.find_by(name: category_name)
  unless category
    puts "  [WARN] Category '#{category_name}' not found. Skipping."
    return
  end

  merchant_matches.each do |keyword|
    rule_name = "Auto: #{keyword} -> #{category_name}"
    
    existing = family.rules.find_by(name: rule_name)
    if existing
      puts "  [SKIP] Rule '#{rule_name}' already exists."
      next
    end

    ActiveRecord::Base.transaction do
      rule = family.rules.new(
        name: rule_name,
        resource_type: "transaction",
        active: true
      )

      # Condition: Name contains keyword
      rule.conditions.build(
        condition_type: "transaction_name",
        operator: "like",
        value: keyword
      )

      # Action: Update Category
      rule.actions.build(
        action_type: "set_transaction_category",
        value: category.id
      )
      
      rule.save!
      puts "  [OK] Created rule '#{rule_name}'"
    end
  end
end

family = Family.first
unless family
  puts "No family found. Please create a user/family first."
  exit
end

puts "Seeding rules for Family: #{family.name}..."

# Rules Definition (Brazilian Context)
# format: [ "Rule Group Name", [ "keyword1", "keyword2" ], "Target Category" ]
rules_data = [
  # Transport
  [ "Uber/99", ["Uber", "99Pop", "99*Pop", "Uber *Trip"], "Transportation" ],
  [ "Posto Gasolina", ["Posto", "Ipiranga", "Shell", "Petrobras"], "Transportation" ],
  [ "Pedágio", ["Sem Parar", "Conectcar", "Auto Expresso"], "Transportation" ],

  # Food
  [ "Delivery", ["iFood", "Rappi", "Uber Eats", "Zé Delivery"], "Food & Drink" ],
  [ "Mercado", ["Carrefour", "Pao de Acucar", "Assai", "Atacadao", "Extra", "Supermercado"], "Groceries" ],
  [ "Padaria", ["Padaria", "Panificadora"], "Food & Drink" ],

  # Services
  [ "Streaming", ["Netflix", "Spotify", "Amazon Prime", "Disney+", "HBO", "Apple.com/bill"], "Entertainment" ],
  [ "Cloud/Tech", ["AWS", "Amazon Web Services", "Heroku", "DigitalOcean", "Google Cloud"], "Services" ],
  
  # Utilities
  [ "Internet/TV", ["Claro", "Vivo", "Tim", "Oi", "Net Servicos"], "Utilities" ],
  [ "Energy", ["Enel", "Light", "Cemig", "Copel", "CPFL"], "Utilities" ]
]

rules_data.each do |group_name, keywords, category_name|
  create_rule(family, group_name, keywords, category_name)
end

puts "Done!"
