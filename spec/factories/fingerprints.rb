FactoryBot.define do
  factory :fingerprint_station do
    sequence(:name) { |n| "PC #{n}" }
    created_by { association(:user, :admin) }

    trait :paired do
      token_digest { FingerprintStation.digest("token-#{name.parameterize}") }
      paired_at { Time.current }
    end
  end

  factory :fingerprint do
    person
    finger { "right_index" }
    template { Base64.strict_encode64(Random.bytes(600)) }
    consented_at { Time.current }
    created_by { association(:user, :admin) }
  end
end
