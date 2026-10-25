FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Zona #{("a".."zz").to_a[n % 702].capitalize}" }
  end

  factory :hauler do
    person
    price_per_pound { 0.3 }
  end

  factory :hauler_payment do
    hauler
    association :created_by, factory: :user
    amount { 100 }
    paid_on { Time.zone.today }
    payment_method { "cash" }
  end

  factory :producer do
    person
    kind { "producer" }

    # The zone is the person's: create(:producer, zone:) puts it there.
    transient { zone { nil } }
    after(:build) { |producer, context| producer.person.zone = context.zone if context.zone }
  end

  factory :purchase do
    producer
    association :created_by, factory: :user
    purchased_at { Time.current }
    coffee_state { "wet_parchment" }
    gross_weight { 146 }
    humidity_percent { coffee_state == "cherry" ? nil : 51 }
    damage_percent { coffee_state == "cherry" ? nil : 0 }
    damage_types { coffee_state != "cherry" && damage_percent.to_d.positive? ? %w[borer] : [] }
    yield_factor { coffee_state == "cherry" ? 0.186 : nil }
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
