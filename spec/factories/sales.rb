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

  factory :carrier do
    sequence(:name) { |n| "Transportes #{n}" }
  end

  factory :truck do
    sequence(:plate) { |n| format("HAA %04d", n) }
    brand_model { "Isuzu NPR" }
  end
end
