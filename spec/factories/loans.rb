FactoryBot.define do
  factory :loan do
    person
    association :created_by, factory: :user
    principal { 10_000 }
    monthly_interest_rate { 3 }
    disbursed_on { Time.zone.today - 60 }
    due_on { Time.zone.today + 60 }
  end

  factory :loan_payment do
    loan
    association :created_by, factory: :user
    paid_on { Time.zone.today }
    amount { 1_000 }
    payment_method { "cash" }
  end
end
