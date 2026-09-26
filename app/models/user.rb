class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :permissions, dependent: :destroy

  accepts_nested_attributes_for :permissions

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, field_format: :email, length: { maximum: 254 }
  validates :password, field_format: :password, allow_nil: true
  validate :keeps_an_active_admin, on: :update

  scope :active, -> { where(active: true) }
  scope :active_admins, -> { active.where(admin: true) }

  # Single decision point for permissions. Inactive users can do nothing;
  # admins can do everything; everyone else needs the module's flag.
  def can?(module_key, action)
    module_key = module_key.to_s
    action = action.to_s
    raise ArgumentError, "unknown module: #{module_key}" unless AppModule::KEYS.include?(module_key)
    raise ArgumentError, "unknown action: #{action}" unless AppModule::ACTIONS.include?(action)

    return false unless active?
    return true if admin?

    permission_for(module_key)&.allows?(action) || false
  end

  def permission_for(module_key)
    permissions.detect { |permission| permission.module_key == module_key.to_s }
  end

  # Builds the missing rows so the permissions form always shows every module.
  def build_missing_permissions
    AppModule::KEYS.each do |key|
      permissions.build(module_key: key) unless permission_for(key)
    end
    permissions
  end

  private
    def keeps_an_active_admin
      was_active_admin = active_in_database && admin_in_database
      return unless was_active_admin && !(active? && admin?)
      return if User.active_admins.where.not(id: id).exists?

      errors.add(:base, :last_active_admin)
    end
end
