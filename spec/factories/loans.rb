FactoryBot.define do
  factory :loan do
    person
    created_by { SpecOwner.user || association(:user) }
    cash_amount { 10_000 }
    monthly_interest_rate { 3 }
    disbursed_on { Time.zone.today - 60 }
    due_on { Time.zone.today + 60 }
  end

  factory :loan_payment do
    loan
    created_by { SpecOwner.user || association(:user) }
    paid_on { Time.zone.today }
    amount { 1_000 }
    payment_method { "cash" }
  end
end

FactoryBot.define do
  factory :supply do
    sequence(:name) { |n| "Abono #{n}" }
    unit { "saco" }
    default_price { 1_000 }
  end

  # A purchase of supplies into the inventory, with its investment (Fernando,
  # 2026-11-12): one line by default (supply, quantity, amount), as many as
  # `lines` brings (2026-11-13).
  factory :supply_entry do
    transient do
      supply { association :supply }
      quantity { 10 }
      amount { 1_000 }
    end
    lines { [ build(:supply_entry_line, supply_entry: instance, supply:, quantity:, amount:) ] }
    received_on { Time.zone.today }
    created_by { SpecOwner.user || association(:user) }
    finance_category_id { create(:finance_category, kind: "investment").id }
    money_account_id { create(:money_account).id }
    payment_method { "cash" }
  end

  factory :supply_entry_line do
    supply
    quantity { 10 }
    amount { 1_000 }
  end

  # Supplies sold apart or used by the business (Fernando, 2026-11-14); a
  # sale by default, with what it takes already in the warehouse.
  factory :supply_exit do
    supply { create(:supply_entry).lines.first.supply }
    kind { "sale" }
    exited_on { Time.zone.today }
    quantity { 2 }
    person
    unit_price { 1_000 }
    payment_method { "cash" }
    money_account
    created_by { SpecOwner.user || association(:user) }
  end
end
