# One row per (user, module) with a flag per action.
class Permission < ApplicationRecord
  include Auditable

  belongs_to :user

  validates :module_key, inclusion: { in: AppModule::KEYS }
  validates :module_key, uniqueness: { scope: :user_id }

  def audit_label
    "#{user.email_address}: #{AppModule.human_name(module_key)}"
  end

  def allows?(action)
    public_send("can_#{action}")
  end
end
