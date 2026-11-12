# One row per (user, module, submodule) with a flag per action.
class Permission < ApplicationRecord
  include Auditable

  belongs_to :user

  validates :module_key, inclusion: { in: AppModule::KEYS }
  validates :submodule_key, inclusion: { in: ->(permission) { AppModule::SUBMODULES.fetch(permission.module_key, []) } }
  validates :submodule_key, uniqueness: { scope: %i[user_id module_key] }

  def permission_key = "#{module_key}.#{submodule_key}"

  def audit_label
    "#{user.email_address}: #{human_name}"
  end

  def human_name
    return AppModule.human_name(module_key) if AppModule.single?(module_key)

    "#{AppModule.human_name(module_key)} › #{AppModule.human_submodule(module_key, submodule_key)}"
  end

  def allows?(action)
    public_send("can_#{action}")
  end
end
