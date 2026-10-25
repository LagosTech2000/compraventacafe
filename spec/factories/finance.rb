FactoryBot.define do
  factory :money_account do
    sequence(:name) { |n| "Caja #{n}" }
    kind { "cash" }
    bank_key { kind == "bank" ? "other" : nil }
    bank_name { kind == "bank" ? "Banco Demo" : nil }
    opening_balance { 0 }
    opening_on { Time.zone.today - 30 }
  end

  factory :finance_category do
    sequence(:name) { |n| "Categoría #{n}" }
    kind { "expense" }
  end

  factory :expense do
    kind { "expense" }
    category { association(:finance_category, kind:) }
    money_account
    association :created_by, factory: :user
    spent_on { Time.zone.today }
    description { "Diésel del camión" }
    amount { 500 }
    payment_method { "cash" }
  end

  factory :other_income do
    money_account
    association :created_by, factory: :user
    received_on { Time.zone.today }
    concept { "Aporte del dueño" }
    amount { 1_000 }
    payment_method { "cash" }
  end

  factory :account_transfer do
    from_account { association(:money_account) }
    to_account { association(:money_account, kind: "bank") }
    association :created_by, factory: :user
    transferred_on { Time.zone.today }
    amount { 300 }
  end

  factory :budget do
    category { association(:finance_category) }
    month { Time.zone.today.beginning_of_month }
    amount { 1_000 }
  end

  factory :staff_role do
    sequence(:name) { |n| "Rol #{n}" }
    salary { 6_000 }
    pay_frequency { "biweekly" }
    overtime_hour_rate { 50 }
  end

  factory :staff_member do
    person { association(:person, :collaborator) }
    role { association(:staff_role) }
    starts_on { Time.zone.today.beginning_of_month }
  end

  factory :staff_advance do
    member { association(:staff_member) }
    money_account
    association :created_by, factory: :user
    given_on { Time.zone.today }
    amount { 500 }
    payment_method { "cash" }
  end

  factory :staff_goal do
    member { association(:staff_member) }
    association :created_by, factory: :user
    period_starts_on { member.period_to_pay&.starts_on || Time.zone.today }
    description { "Ordenar la bodega" }
    bonus_amount { 300 }
  end
end
