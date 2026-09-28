FactoryBot.define do
  factory :permission do
    user
    module_key { "trading" }
  end
end
