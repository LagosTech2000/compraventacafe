FactoryBot.define do
  factory :farm do
    sequence(:name) { |n| "Finca #{n}" }
  end

  factory :expense_category do
    sequence(:name) { |n| "Categoría #{n}" }
  end

  factory :payroll do
    farm
    association :created_by, factory: :user
    sequence(:name) { |n| "Planilla #{n}" }
    kind { "daily" }
    pay_frequency { "weekly" }
    starts_on { Date.new(2026, 9, 1) }
    can_price { kind == "harvest" ? 25 : nil }
  end

  factory :payroll_role do
    payroll
    sequence(:name) { |n| "Rol #{n}" }
    daily_wage { 300 }
  end

  factory :payroll_member do
    payroll
    person { create(:person, :collaborator) }
    role { payroll.daily? ? create(:payroll_role, payroll:) : nil }
  end

  factory :payroll_expense do
    payroll
    association :category, factory: :expense_category
    association :created_by, factory: :user
    spent_on { payroll.starts_on }
    description { "Transporte de personal" }
    amount { 500 }
  end
end
