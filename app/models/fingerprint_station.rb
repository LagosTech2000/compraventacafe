# A PC with a fingerprint reader (Fernando, 2026-11-14). An administrator
# creates it from that PC's browser, which keeps it in a signed cookie
# (COOKIE): what that reader identifies opens there. The bridge on the PC
# pairs with a one-time code (PAIRING_MINUTES) and gets a token; only
# digests of the code and the token are kept. Deactivating it cuts both.
#
# Whether its bridge and reader are connected lives in this process's memory
# (like Presence): one Puma process, async Action Cable.
class FingerprintStation < ApplicationRecord
  include Auditable

  PAIRING_MINUTES = 15
  COOKIE = :fingerprint_station_id

  belongs_to :created_by, class_name: "User"

  normalizes :name, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 80 }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name, :id) }

  attr_reader :pairing_code

  @states = {}
  @states_lock = Mutex.new

  class << self
    # A one-time code typed in the bridge: its station and a new token, once.
    def pair!(code)
      digits = code.to_s.gsub(/\D/, "")
      return if digits.length != 6

      station = active.where("pairing_expires_at > ?", Time.current).find_by(pairing_code_digest: digest(digits))
      return unless station

      token = SecureRandom.base58(40)
      station.update!(token_digest: digest(token), pairing_code_digest: nil, pairing_expires_at: nil, paired_at: Time.current)
      [ station, token ]
    end

    def authenticate(token)
      active.find_by(token_digest: digest(token)) if token.present?
    end

    def digest(value)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("fingerprint stations", 32), value.to_s)
    end

    # { bridge: connected?, reader: connected? } of a station, in this process.
    def state(id) = @states_lock.synchronize { @states.fetch(id, { bridge: false, reader: false }).dup }

    def change_state(id, **state)
      @states_lock.synchronize { @states[id] = @states.fetch(id, { bridge: false, reader: false }).merge(state) }
    end

    def reset_states! = @states_lock.synchronize { @states.clear }
  end

  # A new code for the bridge (the token it had stops working once a bridge pairs).
  def start_pairing!
    @pairing_code = format("%06d", SecureRandom.random_number(1_000_000))
    update!(pairing_code_digest: self.class.digest(@pairing_code), pairing_expires_at: PAIRING_MINUTES.minutes.from_now)
  end

  def paired? = token_digest.present?
  def pairing? = pairing_expires_at&.future?
  def state = self.class.state(id)
  def audit_label = name

  def deactivate!
    update!(active: false, token_digest: nil, pairing_code_digest: nil, pairing_expires_at: nil)
    self.class.change_state(id, bridge: false, reader: false)
  end

  def seen!
    update_columns(last_seen_at: Time.current)
  end
end
