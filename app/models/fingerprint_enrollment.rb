# Registering a finger at a station (Fernando, 2026-11-14): an administrator
# asks from the person's page, with the person's consent; the bridge of that
# PC takes the finger CAPTURES times and sends the template, or that it is
# already someone else's. The request waits in this process's memory
# (one Puma process) up to TTL; the fingerprint is saved as the
# administrator who asked.
class FingerprintEnrollment
  CAPTURES = 3
  TTL = 3.minutes
  REASONS = %w[mismatch timeout merge no_reader busy].freeze

  @pending = {}
  @lock = Mutex.new

  Request = Data.define(:id, :station_id, :person_id, :finger, :user_id, :session_id, :consented_at, :expires_at)

  class << self
    def start!(station:, person:, finger:, user:)
      id = SecureRandom.uuid
      request = Request.new(id:, station_id: station.id, person_id: person.id, finger:, user_id: user.id, session_id: Current.session&.id,
                            consented_at: Time.current, expires_at: TTL.from_now)
      @lock.synchronize do
        @pending.delete_if { |_, pending| pending.expires_at.past? }
        @pending[id] = request
      end
      FingerprintBridgeChannel.broadcast_to(station, { type: "enroll", request_id: id, captures: CAPTURES,
                                                       person: person.full_name, finger: Fingerprint.human_attribute_name("finger/#{finger}") })
      id
    end

    # The request of that station, still waiting.
    def find(id, station:)
      request = @lock.synchronize { @pending[id.to_s] }
      new(request) if request && request.station_id == station.id && request.expires_at.future?
    end

    def failure_message(reason)
      I18n.t("administration.fingerprints.failures.#{REASONS.include?(reason.to_s) ? reason : "other"}")
    end

    def clear! = @lock.synchronize { @pending.clear }

    def forget(id) = @lock.synchronize { @pending.delete(id) }
  end

  attr_reader :request

  def initialize(request)
    @request = request
  end

  def forget! = self.class.forget(request.id)

  # [fingerprint, nil] once saved, or [nil, message].
  def complete!(template:, duplicate_fid:)
    forget!
    if duplicate_fid.present? && (other = Fingerprint.includes(:person).find_by(id: duplicate_fid))
      return [ nil, I18n.t("administration.fingerprints.failures.duplicate", name: other.person.full_name, finger: other.human_finger) ]
    end

    # Saved as the administrator who asked: their session gives the audit its user.
    user = User.find_by(id: request.user_id)
    session = Session.find_by(id: request.session_id, user_id: request.user_id)
    fingerprint = Current.set(session:) do
      Fingerprint.create(person_id: request.person_id, finger: request.finger, template:, consented_at: request.consented_at, created_by: user)
    end
    fingerprint.persisted? ? [ fingerprint, nil ] : [ nil, fingerprint.errors.full_messages.to_sentence ]
  end
end
