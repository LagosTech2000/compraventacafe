FactoryBot.define do
  factory :user do
    name { "Usuario de Prueba" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { AuthenticationHelpers::PASSWORD }

    trait :admin do
      admin { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
