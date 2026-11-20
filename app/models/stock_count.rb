# A physical count of one coffee state in one warehouse (Fernando,
# 2026-11-18: «me interesa lo del ajuste de inventario»): the gross pounds
# counted (and the sacks, optional) at a moment, against what the system
# said then (kept as it was: system_gross, system_net). Its adjustment is
# the difference, which leaves the stock as counted:
#
# - gross_weight: counted − what the system said (+ found more, − less).
# - net_weight: counted × the state's net/gross proportion in that
#   warehouse then (or CoffeeConversion.ratio_for without stock) − the net
#   the system said.
#
# The adjustment enters everything: stock (CoffeeStock), lots (CoffeeLots:
# less takes from the oldest lots and its value is a loss in lempiras; more
# comes in as a lot with no cost), the kardex (StockLedger), the net check
# (StockCheck), the day's reconciliation and the reports. With a
# difference it needs its reason. An adjustment over the share of the stock
# set in Configuración del sitio (count_admin_percent, 2 % to start) is
# for administrators. Decisions of implementation, pending the client's
# confirmation (Fernando, 2026-11-18: «toma las mejores decisiones y luego
# el cliente decide»).
#
# Not edited, never deleted: an administrator voids it, with a reason,
# while no later count of that state and warehouse was made on it.
#
# Its first count of a state and warehouse turns on the stock guard: from
# then on nothing takes more than there is (StockGuard).
class StockCount < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include DayLock
  locks_day :counted_at
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_007
  MAX_WEIGHT = 1_000_000_000
  REASONS = %w[drying scale_error loss surplus initial_count other].freeze

  belongs_to :warehouse
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true

  normalizes :reason_detail, :void_reason, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :counted_at, presence: true
  validates :counted_at, not_in_future: true
  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :counted_gross, numericality: { greater_than_or_equal_to: 0, less_than: MAX_WEIGHT }
  validates :counted_sacks, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 1_000_000 }, allow_nil: true
  validates :reason, inclusion: { in: REASONS }, allow_nil: true
  validates :reason, presence: true, if: :difference?
  validates :reason_detail, presence: true, if: -> { reason == "other" }
  validates :reason_detail, :void_reason, length: { maximum: 200 }
  validates :observations, length: { maximum: 500 }
  validate :warehouse_active, on: :create
  validate :within_the_users_share, on: :create
  validate :last_of_its_kind, on: :create

  before_validation :read_the_system, on: :create
  before_create :assign_number

  scope :active, -> { where(voided_at: nil) }
  scope :newest_first, -> { order(counted_at: :desc, id: :desc) }

  def self.next_number = (maximum(:number) || 0) + 1

  # Whether a state and warehouse were counted by a moment: from then on
  # the stock guard holds.
  def self.counted?(coffee_state, warehouse_id, moment)
    moment.present? && active.where(coffee_state:, warehouse_id:, counted_at: ..moment).exists?
  end

  def display_number = format("%04d", number.to_i)
  def label = I18n.t("sales.stock_counts.label", number: display_number)
  def audit_label = "#{label} · #{warehouse&.name}"
  def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  def human_reason = reason && self.class.human_attribute_name("reason/#{reason}")
  def voided? = voided_at.present?
  def difference? = gross_weight.to_d.nonzero? || net_weight.to_d.nonzero?
  def surplus? = net_weight.to_d.positive?
  def shortage? = net_weight.to_d.negative?

  # The adjustment against what the system said, in % of its gross pounds
  # (nil when the system had none).
  def difference_percent
    system_gross.to_d.positive? ? (gross_weight.to_d * 100 / system_gross).round(2) : nil
  end

  # What the system said, in a CoffeeStock row of that moment.
  def system_row = CoffeeStock.new(warehouse:, at: counted_at).row(coffee_state)

  # A later count of its state and warehouse was made on its adjustment.
  def later_count = StockCount.active.where(coffee_state:, warehouse_id:).where("counted_at > ? OR (counted_at = ? AND id > ?)", counted_at, counted_at, id).order(:counted_at, :id).first

  def voidable? = !voided? && later_count.nil?

  def void!(user, reason:)
    errors.clear
    transaction do
      lock!
      errors.add(:base, :already_voided) if voided?
      errors.add(:void_reason, :blank) if reason.to_s.squish.empty?
      if (later = later_count)
        errors.add(:base, :later_count, number: later.display_number)
      end
      raise ActiveRecord::RecordInvalid, self if errors.any?

      update!(voided_at: Time.current, voided_by: user, void_reason: reason)
    end
  end

  private
    # What the system said at that moment and the adjustment that leaves it as counted.
    def read_the_system
      return unless warehouse && coffee_state.in?(Purchase::COFFEE_STATES) && counted_at && counted_gross

      row = system_row
      self.system_gross = row.gross_stock.to_d.round(2)
      self.system_net = row.stock.to_d.round(2)
      ratio = if system_gross.positive? && system_net.positive? then system_net / system_gross
      else CoffeeConversion.ratio_for(coffee_state, counted_at.to_date).first
      end
      self.gross_weight = (counted_gross.to_d - system_gross).round(2)
      # Counted as the system said: nothing to adjust (not a cent of rounding).
      self.net_weight = gross_weight.zero? ? 0 : ((counted_gross.to_d * ratio).round(2) - system_net).round(2)
    end

    def warehouse_active
      errors.add(:warehouse, :inactive) if warehouse && !warehouse.active?
    end

    # Over the share set in the site settings, only an administrator adjusts.
    def within_the_users_share
      return unless difference? && created_by && !created_by.admin?

      limit = SiteSetting.current.count_admin_percent.to_d
      percent = difference_percent
      return if percent && percent.abs <= limit

      errors.add(:counted_gross, :over_share, percent: ActiveSupport::NumberHelper.number_to_rounded(limit, precision: 2, strip_insignificant_zeros: true))
    end

    # A count goes after the last one of its state and warehouse: what came
    # before was already counted.
    def last_of_its_kind
      return unless warehouse_id && coffee_state && counted_at

      last = StockCount.active.where(warehouse_id:, coffee_state:).maximum(:counted_at)
      errors.add(:counted_at, :before_last_count, date: I18n.l(last.in_time_zone)) if last && counted_at < last
    end

    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end
end
