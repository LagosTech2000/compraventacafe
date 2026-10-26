FactoryBot.define do
  factory :buyer do
    sequence(:name) { |n| "Exportadora Demo #{n}" }
    kind { "exporter" }
  end

  # A truck that left with wet parchment: 1,000 lb gross, 6 sacks, 51 %
  # humidity → (1,000 − 6) × 0.49 = 487.06 lb net. `received` weighs it at
  # the buyer's too.
  factory :shipment do
    buyer
    association :created_by, factory: :user
    departed_at { Time.current }
    coffee_state { "wet_parchment" }
    origin_gross_weight { 1_000 }
    origin_sacks { 6 }
    origin_humidity_percent { coffee_state == "cherry" ? nil : 51 }
    origin_damage_percent { coffee_state == "cherry" ? nil : 0 }
    origin_yield_factor { coffee_state == "cherry" ? 0.186 : nil }

    trait :received do
      received_on { departed_at.to_date }
      destination_gross_weight { 990 }
      destination_sacks { 6 }
      destination_humidity_percent { coffee_state == "cherry" ? nil : 51 }
      destination_damage_percent { coffee_state == "cherry" ? nil : 0 }
      destination_yield_factor { coffee_state == "cherry" ? 0.186 : nil }
    end
  end

  # A sale of received shipments (SaleIssuer), pending unless told.
  factory :sale do
    transient do
      shipments { [ association(:shipment, :received, buyer:) ] }
      payment_status { "pending" }
      amount { nil }
      user { association(:user) }
    end
    buyer
    price_unit { "quintal" }
    unit_price { 6_000 }
    sold_on { Time.zone.today }

    initialize_with do
      SaleIssuer.new(buyer:, user:, shipment_ids: shipments.map(&:id), payment_status:, payment_method: "transfer", amount:,
                     sale: { sold_on:, price_unit:, unit_price: }).call.sale
    end
    to_create { |sale| raise ActiveRecord::RecordInvalid, sale unless sale.persisted? }
  end

  factory :sale_payment do
    sale
    association :created_by, factory: :user
    amount { 100 }
    paid_on { Time.zone.today }
    payment_method { "cash" }
  end

  # Cherry weighed to become wet parchment (in process); `finished` weighs
  # what came out (sacks, humidity, damage).
  factory :processing_site do
    sequence(:name) { |n| "Máquina ecológica #{n}" }
  end

  factory :coffee_conversion do
    from_state { "cherry" }
    processing_site
    estimated_yield_percent { from_state == "cherry" ? 37.95 : 50 }
    weighed_at { Time.current }
    input_gross_weight { 1_000 }
    association :created_by, factory: :user

    trait :finished do
      finished_at { weighed_at + 1.hour }
      output_gross_weight { 400 }
      output_sacks { 4 }
      output_humidity_percent { 51 }
      finishing { true }
    end
  end

  factory :warehouse do
    sequence(:name) { |n| "Bodega de prueba #{n}" }
  end

  # Moves wet parchment from the default warehouse to another one.
  factory :warehouse_transfer do
    from_warehouse { Warehouse.main! }
    to_warehouse { association(:warehouse) }
    association :created_by, factory: :user
    transferred_at { Time.current }
    coffee_state { "wet_parchment" }
    net_weight { 100 }
  end

  # L 500 of freight, paid in cash.
  factory :processing_cost do
    coffee_conversion
    association :created_by, factory: :user
    concept { "freight" }
    pricing { "total" }
    amount { 500 }
    paid_on { Time.zone.today }
    payment_method { "cash" }
  end

  factory :carrier do
    sequence(:name) { |n| "Transportes #{n}" }
  end

  factory :truck do
    sequence(:plate) { |n| format("HAA %04d", n) }
    brand_model { "Isuzu NPR" }
  end

  factory :buyer_advance do
    buyer
    money_account
    association :created_by, factory: :user
    received_on { Time.zone.today }
    amount { 10_000 }
    payment_method { "transfer" }
  end
end
