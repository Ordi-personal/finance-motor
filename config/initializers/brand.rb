Rails.application.configure do
  brand_name = ENV.fetch("BRAND_NAME", "Ordi")

  config.x.brand_name = brand_name
  config.x.product_name = ENV.fetch("PRODUCT_NAME", "#{brand_name} Finanças")
end
