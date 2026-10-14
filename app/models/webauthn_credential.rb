# A passkey of one of the user's devices (fingerprint, face or the device's
# lock), registered from Mi configuración (Fernando, 2026-10-13). It is one
# more way to sign in: the password keeps working. Only the public key is
# stored; the private one never leaves the device.
class WebauthnCredential < ApplicationRecord
  include Auditable

  # The key and its counter change on every sign-in: not business data.
  self.audit_skipped_attributes = %w[public_key sign_count last_used_at]

  belongs_to :user

  normalizes :nickname, with: ->(value) { value.squish.presence }

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :nickname, presence: true, length: { maximum: 60 }

  scope :ordered, -> { order(:created_at) }

  def audit_label = I18n.t("webauthn_credentials.audit_label", nickname:, user: user&.name)
end
