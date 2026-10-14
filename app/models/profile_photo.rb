# The profile photo of a Person or a User (HasPhoto, Fernando 2026-10-13).
# Its bytes live in the database, as the site logo's; it is served by
# ProfilePhotosController. The browser shrinks the picture before sending it
# (photo_input_controller.js), so a phone's photo fits MAX_SIZE.
class ProfilePhoto < ApplicationRecord
  include Auditable

  MAX_SIZE = 1.megabyte
  # Only JPEG, PNG and WebP, checked by their content (SVG can carry scripts).
  SIGNATURES = SiteSetting::LOGO_SIGNATURES.slice("image/jpeg", "image/png", "image/webp").freeze

  self.audit_skipped_attributes = %w[data]

  belongs_to :owner, polymorphic: true

  validates :content_type, inclusion: { in: SIGNATURES.keys }
  validates :byte_size, numericality: { less_than_or_equal_to: MAX_SIZE }

  # The image format of these bytes, or nil if they are not one taken.
  def self.content_type_of(bytes)
    SIGNATURES.find { |_, matches| matches.call(bytes) }&.first
  end

  def audit_label = I18n.t("profile_photos.audit_label", owner: owner.try(:full_name) || owner.try(:name))

  # Changes when the photo does, so browsers keep it cached until then.
  def version = updated_at.to_i
end
