FactoryBot.define do
  factory :person do
    first_names { "María José" }
    sequence(:last_names) { |n| "López Rivera #{n}" }

    trait :client do
      after(:create) { |person| create(:client, person: person) }
    end

    trait :collaborator do
      after(:create) { |person| create(:collaborator, person: person) }
    end
  end

  factory :client do
    person
  end

  factory :collaborator do
    person
  end
end
