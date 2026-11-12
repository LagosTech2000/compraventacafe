FactoryBot.define do
  # With a submodule, that one row. Without it, the whole module: one row per
  # submodule with the same flags (the record returned is the first one).
  factory :permission do
    user
    module_key { "trading" }
    submodule_key { nil }

    to_create do |permission|
      if permission.submodule_key
        permission.save!
      else
        first, *rest = AppModule.submodules(permission.module_key)
        permission.submodule_key = first
        permission.save!
        rest.each do |submodule_key|
          Permission.create!(permission.attributes.except("id", "created_at", "updated_at").merge("submodule_key" => submodule_key))
        end
      end
    end
  end
end
