# What identifies the business on screen and on paper: its name (navigation
# bar, browser tab, sign-in page and printed documents), its location
# (sign-in page and printed documents), its RTN (invoices; optional, 14
# digits like a person's) and its logo (the home button of the
# navigation bar and the sign-in page). Admins set it in Administración →
# Configuración del sitio.
#
# One row. Until an admin saves it, the values come from es.yml (negocio.*).
# The logo's bytes are stored in the row and served by SiteLogosController;
# only PNG, JPEG, WebP and GIF are taken, checked by their content (not by
# the name or type the browser sends). SVG is refused: it can carry scripts.
class SiteSetting < ApplicationRecord
  include Auditable

  # Bytes each image format starts with.
  LOGO_SIGNATURES = {
    "image/png" => ->(bytes) { bytes.start_with?("\x89PNG\r\n\x1A\n".b) },
    "image/jpeg" => ->(bytes) { bytes.start_with?("\xFF\xD8\xFF".b) },
    "image/gif" => ->(bytes) { bytes.start_with?("GIF87a".b, "GIF89a".b) },
    "image/webp" => ->(bytes) { bytes.byteslice(0, 4) == "RIFF".b && bytes.byteslice(8, 4) == "WEBP".b }
  }.freeze
  MAX_LOGO_SIZE = 1.megabyte
  # Every column but the logo's bytes, for pages that only need to know
  # whether there is a logo.
  LIGHT_COLUMNS = %w[id business_name location rtn logo_content_type logo_filename logo_byte_size created_at updated_at].freeze

  self.audit_skipped_attributes = %w[logo_data]

  # An uploaded file (from the form) and "remove the logo".
  attr_accessor :logo, :remove_logo

  normalizes :business_name, :location, with: ->(value) { value.squish.presence }
  normalizes :rtn, with: FieldFormats::DIGITS

  validates :business_name, presence: true, length: { maximum: 80 }
  validates :location, length: { maximum: 120 }
  validates :rtn, field_format: :rtn
  validate :logo_is_an_image

  before_validation :take_logo

  # The saved settings without the logo's bytes, or the defaults.
  def self.current
    select(LIGHT_COLUMNS).first || new(defaults)
  end

  # The one row, with everything, to edit it.
  def self.instance
    first || new(defaults)
  end

  def self.defaults
    { business_name: I18n.t("negocio.nombre"), location: I18n.t("negocio.ubicacion") }
  end

  def audit_label = self.class.model_name.human

  def logo? = logo_byte_size.to_i.positive?

  # Changes when the logo does, so browsers can keep it cached until then.
  def logo_version = updated_at.to_i

  private
    def take_logo
      if logo.respond_to?(:read)
        @logo_bytes = logo.read.b
        @logo_type = LOGO_SIGNATURES.find { |_, matches| matches.call(@logo_bytes) }&.first
        return unless @logo_type && @logo_bytes.bytesize <= MAX_LOGO_SIZE

        self.logo_data = @logo_bytes
        self.logo_content_type = @logo_type
        self.logo_filename = File.basename(logo.original_filename.to_s).first(255).presence
        self.logo_byte_size = @logo_bytes.bytesize
      elsif ActiveModel::Type::Boolean.new.cast(remove_logo)
        self.logo_data = self.logo_content_type = self.logo_filename = self.logo_byte_size = nil
      end
    end

    def logo_is_an_image
      return unless @logo_bytes

      if @logo_bytes.bytesize > MAX_LOGO_SIZE
        errors.add(:logo, :too_big, size: ActiveSupport::NumberHelper.number_to_human_size(MAX_LOGO_SIZE))
      elsif @logo_type.nil?
        errors.add(:logo, :not_an_image)
      end
    end
end
