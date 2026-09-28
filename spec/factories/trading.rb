FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Zona #{("a".."zz").to_a[n % 702].capitalize}" }
  end

  factory :producer do
    person
    kind { "producer" }
  end

  factory :purchase do
    producer
    association :created_by, factory: :user
    purchased_on { Time.zone.today }
    coffee_state { "wet_parchment" }
    gross_weight { 146 }
    humidity_percent { 51 }
    price_per_pound { 58 }
  end

  factory :invoice do
    producer
    association :created_by, factory: :user
    issued_on { Time.zone.today }
    payment_status { "pending" }
    purchases { [ association(:purchase, producer: producer) ] }
  end
end
