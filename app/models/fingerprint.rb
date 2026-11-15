# A person's fingerprint (Fernando, 2026-11-14): the template of one finger
# made by the ZK9500 bridge (tools/fingerprint_bridge) from three captures,
# with the person's consent. Only administrators register or remove one.
#
# The template (base64, as the bridge sends it) is kept encrypted with a key
# derived from secret_key_base; the image of the finger is never stored. The
# bridges keep every template in the reader's memory to tell who put a
# finger (1:N), so each change tells them to load them again.
class Fingerprint < ApplicationRecord
  include Auditable

  # The finger asked first (Fernando, 2026-11-14).
  RECOMMENDED = "right_index"
  FINGERS = %w[right_index right_thumb right_middle right_ring right_little
               left_index left_thumb left_middle left_ring left_little].freeze
  # Where the bridges listen for "load the templates again".
  BRIDGES_STREAM = "fingerprint_bridges"
  MAX_TEMPLATE_BYTES = 4096

  # The «La persona aceptó» box of the form.
  attr_accessor :consent

  belongs_to :person
  belongs_to :created_by, class_name: "User"

  validates :finger, inclusion: { in: FINGERS }, uniqueness: { scope: :person_id }
  validates :consented_at, presence: true
  validate :template_readable

  after_commit :tell_bridges

  def self.cipher
    ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("fingerprint templates", 32))
  end

  # The template as the bridge sent it (base64).
  def template
    template_ciphertext && self.class.cipher.decrypt_and_verify(template_ciphertext)
  end

  def template=(base64)
    @template_bytes = (Base64.strict_decode64(base64.to_s) if base64.present?)
    self.template_ciphertext = (self.class.cipher.encrypt_and_sign(base64.to_s) if @template_bytes)
  rescue ArgumentError
    @template_bytes = nil
    self.template_ciphertext = nil
  end

  def human_finger = self.class.human_attribute_name("finger/#{finger}")
  def audit_label = "#{person&.full_name} · #{human_finger}"

  private
    def template_readable
      if template_ciphertext.blank?
        errors.add(:template, :blank)
      elsif @template_bytes && (@template_bytes.empty? || @template_bytes.bytesize > MAX_TEMPLATE_BYTES)
        errors.add(:template, :invalid)
      end
    end

    def tell_bridges
      ActionCable.server.broadcast(BRIDGES_STREAM, { type: "templates_changed" })
    end
end
