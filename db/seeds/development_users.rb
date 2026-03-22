return unless Rails.env.development?

password = ENV.fetch("DEV_DEFAULT_PASSWORD", "Dev@12345")

users = [
  {
    email: "padre@ordime.local",
    first_name: "Padre",
    last_name: "Ordi",
    family_name: "Paroquia Ordi",
    role: "admin"
  },
  {
    email: "teste@ordime.local",
    first_name: "Teste",
    last_name: "Financeiro",
    family_name: "Familia Teste Sure",
    role: "admin"
  },
  {
    email: "vagner@ordime.app",
    first_name: "Vagner",
    last_name: "Ordi",
    family_name: "Familia Vagner",
    role: "admin"
  }
]

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.family ||= Family.create!(
    name: attrs[:family_name],
    currency: "BRL",
    locale: "pt-BR",
    date_format: "%d/%m/%Y",
    country: "BR",
    timezone: "America/Sao_Paulo",
    month_start_day: 1,
    moniker: "Family",
    assistant_type: "builtin"
  )
  user.first_name = attrs[:first_name]
  user.last_name = attrs[:last_name]
  user.password = password
  user.password_confirmation = password
  user.role = attrs[:role]
  user.active = true
  user.locale = "pt-BR"
  user.ui_layout = "dashboard" if user.respond_to?(:ui_layout=)
  user.onboarded_at ||= Time.current
  user.save!
end

puts "Development users ready for finance-motor:"
users.each { |attrs| puts "- #{attrs[:email]} | senha: #{password}" }
