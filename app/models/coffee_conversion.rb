# Coffee converted from one state to the next (Fernando, 2026-10-25): cherry
# to wet parchment, wet to dry parchment, in two steps:
#
# 1. The gross pounds that go in are weighed: they leave their state at
#    once and are "in process" (CoffeeStock#in_process).
# 2. The coffee that came out in the new state is weighed (one result, it
#    is finished): it adds to that state.
#
# What goes in leaves the stock at the net/gross proportion of its state
# (.ratio_for): the one in stock that day; with no stock of that state, its
# purchases'; with none, the purchase form's defaults (cherry's yield,
# 1 − the parchment's humidity). What comes out is weighed like a purchase
# or a shipment (Fernando, 2026-10-25): gross, counted sacks, humidity and
# damage, with PurchaseCalculation. Results registered before used the
# proportion of the new state instead. The proportion and where it came
# from are kept, so the conversion never changes afterwards.
#
# A conversion in process is voided (never deleted) and its coffee goes
# back; a finished one can have its result removed, back to in process.
class CoffeeConversion < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_005
  # What each state turns into.
  NEXT_STATE = { "cherry" => "wet_parchment", "wet_parchment" => "dry_parchment" }.freeze
  STATUSES = %w[in_process finished voided].freeze
  RATIO_SOURCES = %w[stock purchases default weighed].freeze
  MAX_WEIGHT = 1_000_000_000
  MAX_SACKS = 100_000

  # Where its coffee is taken from, and where the result comes into
  # (client, 2026-10-26): the same one unless chosen.
  belongs_to :warehouse
  belongs_to :output_warehouse, class_name: "Warehouse", optional: true
  # Where it is processed (client, 2026-10-26); the ones before have none.
  belongs_to :processing_site, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :finished_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true

  normalizes :observations, with: FieldFormats::STRIP

  # Set while registering the result (Sales::ConversionResultsController).
  attr_accessor :finishing

  before_validation { self.warehouse ||= Warehouse.main! if new_record? }
  before_validation { self.output_warehouse ||= warehouse if finishing }
  before_validation :set_to_state
  before_validation :weigh_input, if: -> { new_record? || input_gross_weight_changed? || weighed_at_changed? }
  before_validation :weigh_output, if: :finishing

  validates :from_state, inclusion: { in: NEXT_STATE.keys }
  validates :weighed_at, presence: true
  validates :input_gross_weight, numericality: { greater_than: 0, less_than: MAX_WEIGHT }
  # What it should give, in gross pounds of the new state per 100 that go
  # in: only a projection (client, 2026-10-26); the real one is weighed.
  validates :estimated_yield_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, on: :create
  validates :processing_site, presence: true, on: :create
  validates :input_humidity_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }, allow_nil: true
  validates :observations, length: { maximum: 500 }
  with_options if: :finishing do
    validates :finished_at, presence: true
    validates :output_gross_weight, numericality: { greater_than: 0, less_than: MAX_WEIGHT }
    validates :output_sacks, numericality: { only_integer: true, greater_than: 0, less_than: MAX_SACKS }
    validates :output_humidity_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
    validates :output_damage_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  end
  validate :finished_after_weighed, if: :finishing
  validate :warehouses_active

  before_create :assign_number

  scope :active, -> { where(voided_at: nil) }
  scope :in_process, -> { active.where(finished_at: nil) }
  scope :finished, -> { active.where.not(finished_at: nil) }
  scope :newest_first, -> { order(number: :desc) }

  def self.with_status(status)
    case status
    when "in_process" then in_process
    when "finished" then finished
    when "voided" then where.not(voided_at: nil)
    else all
    end
  end

  # [net/gross proportion, where it came from] of a state on a day.
  def self.ratio_for(state, date)
    row = CoffeeStock.new(date).row(state)
    return [ (row.stock / row.gross_stock).round(6), "stock" ] if row.gross_stock.positive? && row.stock.positive?

    purchases = Purchase.active.where(coffee_state: state)
    gross = purchases.sum(:gross_weight)
    net = purchases.sum(:net_weight)
    return [ (net / gross).round(6), "purchases" ] if gross.positive? && net.positive?

    [ default_ratio(state), "default" ]
  end

  # From the purchase form's starting values.
  def self.default_ratio(state)
    inputs = PurchaseDefaults.inputs_for(state)
    inputs[:yield_factor] || (1 - BigDecimal(inputs[:humidity_percent].to_s) / 100)
  end

  # Lempiras added by processing, by conversion id (none yet).
  def self.processing_costs_by_conversion = {}

  # The estimate a new process starts with (site settings): 37.95 % of
  # cherry's gross as wet parchment, 50 % of wet parchment's when dried.
  def self.default_yield_percent(from_state)
    setting = SiteSetting.current
    from_state == "cherry" ? setting.cherry_yield_percent : setting.drying_yield_percent
  end

  # What processes of a state really gave, all together: gross pounds that
  # came out per 100 that went in (nil without finished ones).
  def self.average_yield_percent(from_state)
    finished = self.finished.where(from_state:)
    went_in = finished.sum(:input_gross_weight)
    (finished.sum(:output_gross_weight) * 100 / went_in).round(2) if went_in.positive?
  end

  def self.human_state(state) = Purchase.human_attribute_name("coffee_state/#{state}")

  def display_number = format("%04d", number)
  def audit_label = "#{display_number} · #{human_from_state} → #{human_to_state}"

  def human_from_state = self.class.human_state(from_state)
  def human_to_state = self.class.human_state(to_state)
  def human_status = I18n.t("sales.coffee_conversions.statuses.#{status}")

  def voided? = voided_at.present?
  def finished? = !voided? && finished_at.present?
  def in_process? = !voided? && finished_at.nil?

  def status
    if voided? then "voided"
    elsif finished? then "finished"
    else "in_process"
    end
  end

  def input_quintals = PurchaseCalculation.quintals(input_net_weight)
  def output_quintals = output_net_weight && PurchaseCalculation.quintals(output_net_weight)

  # Net pounds that came out minus the ones that went in (Fernando,
  # 2026-10-25): below zero, the coffee gave less than what was paid for.
  def net_difference = output_net_weight && (output_net_weight - input_net_weight)
  def net_difference_percent = net_difference && input_net_weight.positive? ? (net_difference / input_net_weight * 100).round(1) : nil
  # The gross pounds it should give (nil for the ones before estimates).
  def estimated_output_gross = estimated_yield_percent && (input_gross_weight * estimated_yield_percent / 100).round(2)

  # What it really gave: gross pounds out per 100 in.
  def output_yield_percent = output_gross_weight && input_gross_weight.positive? ? (output_gross_weight * 100 / input_gross_weight).round(2) : nil

  # Real − estimated gross pounds: below zero, it gave less than expected.
  def estimate_difference = output_gross_weight && estimated_output_gross && (output_gross_weight - estimated_output_gross)

  # Shrink (merma): the gross pounds lost between going in and coming out.
  def shrink_weight = output_gross_weight && (input_gross_weight - output_gross_weight)
  def shrink_percent = shrink_weight && input_gross_weight.positive? ? (shrink_weight * 100 / input_gross_weight).round(2) : nil

  # Pounds the damage took off what came out, as in a purchase.
  def output_damage_weight
    return 0 unless output_weighed? && to_state != "cherry"

    PurchaseCalculation.new(coffee_state: to_state, gross_weight: output_gross_weight, price_per_pound: 0, humidity_percent: output_humidity_percent,
                            damage_percent: output_damage_percent, counted_sacks: output_sacks).damage_weight.to_d
  end

  # The result was weighed with humidity and damage (not with the stock's proportion).
  def output_weighed? = output_ratio_source == "weighed"

  # Voids a conversion in process: its coffee goes back to its state.
  def void!(user)
    raise ActiveRecord::RecordInvalid, tap { errors.add(:base, :finished) } unless in_process?

    update!(voided_at: Time.current, voided_by: user)
  end

  # Takes the result off: back to in process.
  def reopen!
    raise ActiveRecord::RecordInvalid, tap { errors.add(:base, :not_finished) } unless finished?

    self.finishing = false
    update!(finished_at: nil, finished_by: nil, output_warehouse: nil, output_gross_weight: nil, output_net_weight: nil, output_ratio: nil, output_ratio_source: nil,
            output_sacks: nil, output_tare: nil, output_humidity_percent: nil, output_damage_percent: nil)
  end

  private
    def set_to_state
      self.to_state = NEXT_STATE[from_state]
    end

    def weigh_input
      return unless from_state.in?(NEXT_STATE.keys) && weighed_at && input_gross_weight.to_d.positive?

      self.input_ratio, self.input_ratio_source = self.class.ratio_for(from_state, weighed_at.to_date)
      self.input_net_weight = (input_gross_weight * input_ratio).round(2)
    end

    def weigh_output
      self.output_damage_percent ||= 0 # empty counts as 0 %, as in purchases
      return unless to_state && output_gross_weight.to_d.positive? && output_sacks.to_i.positive? && output_humidity_percent.present?

      calculation = PurchaseCalculation.new(coffee_state: to_state, gross_weight: output_gross_weight, price_per_pound: 0,
                                            humidity_percent: output_humidity_percent, damage_percent: output_damage_percent,
                                            counted_sacks: output_sacks)
      self.output_tare = calculation.tare
      self.output_net_weight = calculation.net_weight
      self.output_ratio = (calculation.net_weight / output_gross_weight).round(6)
      self.output_ratio_source = "weighed"
    end

    def finished_after_weighed
      errors.add(:finished_at, :before_weighed) if finished_at && weighed_at && finished_at < weighed_at
    end

    def warehouses_active
      errors.add(:warehouse, :inactive) if will_save_change_to_warehouse_id? && warehouse && !warehouse.active?
      errors.add(:output_warehouse, :inactive) if will_save_change_to_output_warehouse_id? && output_warehouse && !output_warehouse.active?
      errors.add(:processing_site, :inactive) if will_save_change_to_processing_site_id? && processing_site && !processing_site.active?
    end

    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end
end
