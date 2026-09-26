# One row per (user, module) with a flag per action.
class Permission < ApplicationRecord
  belongs_to :user

  validates :module_key, inclusion: { in: AppModule::KEYS }
  validates :module_key, uniqueness: { scope: :user_id }

  def allows?(action)
    public_send("can_#{action}")
  end
end
