# A truck that leaves with coffee for a buyer ("salida de camión",
# Fernando, 2026-10-23). It is weighed on the local scale before leaving
# (origin) and again on the buyer's scale (destination). Each net weight
# uses the purchase calculation (PurchaseCalculation) with the sacks
# counted: (gross − 1 lb × sacks) × (1 − humidity%) × (1 − damage%), or
# × yield for cherry.
#
# The stock goes down by the origin net (CoffeeStock). The difference
# between both scales is shown, and stands out when it passes the
# tolerance of the site settings. A sale (Sale) charges the destination net.
#
# Stages: in transit → received (weighed at destination) → sold; or voided.
# Weights are kept as calculated: they change only when an input does.
# A shipment in a sale is not changed nor voided; voided, its coffee is
# back in stock.
class Shipment < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_002
  STATUSES = %w[in_transit received sold voided].freeze
  SIDES = %w[origin destination].freeze
  MAX_WEIGHT = 1_000_000
  MAX_SACKS = 10_000
  # What each side's calculation reads.
  INPUTS = %w[gross_weight sacks humidity_percent damage_percent yield_factor].freeze
  # The local scale: the gross weight and sacks typed, or the sums of
  # weighings (ShipmentWeighing), as in the purchases.
  WEIGHT_MODES = Purchase::WEIGHT_MODES

  belongs_to :buyer
  # The warehouse it leaves from (client, 2026-10-26).
  belongs_to :warehouse
  # Who hauled it and in what truck (catalogs apart), and who drove it: an
  # employee of the Planilla interna, or a name typed (Fernando, 2026-10-25).
  # A carrier or a driver, one or the other (client, 2026-10-30); with a
  # carrier, optionally what it is paid for the trip (#trip_price).
  belongs_to :carrier, optional: true
  belongs_to :truck, optional: true
  belongs_to :driver, class_name: "StaffMember", optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true
  has_many :sale_lines, dependent: :restrict_with_error
  has_one :active_sale_line, -> { where(active: true) }, class_name: "SaleLine", inverse_of: :shipment
  has_one :sale, through: :active_sale_line
  has_many :weighings, -> { order(:id) }, class_name: "ShipmentWeighing", dependent: :destroy, inverse_of: :shipment
  accepts_nested_attributes_for :weighings, allow_destroy: true, reject_if: :blank_weighing?

  normalizes :remission_number, :weight_note_number, :driver_name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :departed_at, presence: true
  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :origin_weight_mode, inclusion: { in: WEIGHT_MODES }
  validate :weighings_present, if: :by_weighings?
  validates :remission_number, :weight_note_number, length: { maximum: 60 }
  validates :driver_name, length: { maximum: 120 }
  validates :trip_price, numericality: { greater_than: 0, less_than: 100_000_000 }, allow_nil: true
  validate :carrier_or_driver, if: -> { will_save_change_to_carrier_id? || will_save_change_to_driver_id? || will_save_change_to_driver_name? }
  validate :carrier_and_truck_active
  validate :warehouse_active, if: :will_save_change_to_warehouse_id?
  validates :observations, length: { maximum: 500 }
  validates :origin_gross_weight, numericality: { greater_than: 0, less_than: MAX_WEIGHT }
  validates :origin_sacks, numericality: { only_integer: true, greater_than: 0, less_than: MAX_SACKS }
  validate :inputs_of_origin
  validate :destination_complete, if: -> { receiving || destination_entered? }
  validate :received_after_departure
  validate :buyer_active, if: :will_save_change_to_buyer_id?
  validate :not_sold, on: :update

  # First: by weighings, the local gross weight and sacks come from them.
  before_validation { self.warehouse ||= Warehouse.main! if new_record? }
  before_validation :sum_weighings
  before_validation :clear_unused_inputs
  before_validation -> { calculate("origin") }, if: -> { recalculate?("origin") }
  before_validation -> { calculate("destination") }, if: -> { recalculate?("destination") }
  before_validation :assign_season
  # The employee chosen as driver wins over a name typed.
  before_validation { self.driver_name = nil if driver_id }
  # Only when the form chose (an arrival or a void leaves the old ones as they are).
  before_validation :keep_one_transport, if: -> { @transport_mode.present? }
  before_create :assign_number

  # Set when the destination weighing is saved: then it is required.
  attr_accessor :receiving

  TRANSPORT_MODES = %w[carrier driver].freeze
  # What the form chose: a carrier or a driver. The other one is cleared.
  attr_writer :transport_mode

  def transport_mode
    @transport_mode.presence_in(TRANSPORT_MODES) || (driver_id || driver_name.present? ? "driver" : "carrier")
  end

  # The number the next shipment takes (shown in «Nueva salida»; the real
  # one is given when saving, so two at once still get their own).
  def self.next_number = (maximum(:number) || 0) + 1

  scope :active, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  scope :in_transit, -> { active.where(received_on: nil) }
  scope :received, -> { active.where.not(received_on: nil) }
  scope :sold, -> { active.where(id: SaleLine.active.select(:shipment_id)) }
  # Weighed at destination and waiting for a sale.
  scope :unsold, -> { received.where.not(id: SaleLine.active.select(:shipment_id)) }
  scope :on, ->(dates) { where(departed_at: Purchase.day_range(dates)) }
  scope :received_on_day, ->(date) { where(received_on: date) }
  scope :newest_first, -> { order(departed_at: :desc, id: :desc) }

  def self.with_status(status)
    case status
    when "in_transit" then in_transit
    when "received" then unsold
    when "sold" then sold
    when "voided" then voided
    else all
    end
  end

  def display_number = format("%04d", number)

  # Who drove it: the employee chosen, or the name typed.
  def driver_label = driver&.full_name || driver_name

  def audit_label = "#{display_number} · #{buyer&.name}"

  def voided? = voided_at.present?
  def received? = received_on.present?
  def sold? = active_sale_line.present?
  def cherry? = coffee_state == "cherry"
  def by_weighings? = origin_weight_mode == "weighings"

  # Weighings that stay after saving (the form may mark some for removal).
  def kept_weighings = weighings.reject(&:marked_for_destruction?)

  def status
    if voided? then "voided"
    elsif sold? then "sold"
    elsif received? then "received"
    else "in_transit"
    end
  end

  def human_status = self.class.human_attribute_name("status/#{status}")
  def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")

  def season = Season.new(season_year)

  # QQ of 125 lb, as the purchases count them.
  def origin_quintals = PurchaseCalculation.quintals(origin_net_weight)
  def destination_quintals = destination_net_weight && PurchaseCalculation.quintals(destination_net_weight)

  # Destination net − origin net: negative when the buyer's scale gave less.
  def net_difference
    destination_net_weight - origin_net_weight if destination_net_weight
  end

  def difference_percent
    return unless net_difference && origin_net_weight.positive?

    (net_difference * 100 / origin_net_weight).round(2)
  end

  # Over the tolerance either way (more or less). No tolerance set: never.
  def over_tolerance?(tolerance = WeightTolerance.percent)
    tolerance.present? && difference_percent.present? && difference_percent.abs > tolerance
  end

  # Takes its coffee out of the shipments and back to stock. Only while it
  # is in no sale.
  def void!(user)
    update!(voided_at: Time.current, voided_by: user)
  end

  def voidable? = !voided? && !sold?

  def destination_entered?
    received_on.present? || INPUTS.any? { |input| public_send("destination_#{input}").present? }
  end

  private
    def blank_weighing?(attributes)
      attributes["id"].blank? && attributes.values_at("gross_weight", "sacks").all?(&:blank?)
    end

    # By weighings, the local gross weight and sacks are their sums (never
    # typed). Back to one figure, the old weighings are removed.
    def sum_weighings
      if by_weighings?
        kept = kept_weighings
        self.origin_gross_weight = kept.sum { |weighing| weighing.gross_weight.to_d }
        self.origin_sacks = kept.sum { |weighing| weighing.sacks.to_i }
      elsif will_save_change_to_origin_weight_mode?
        weighings.each(&:mark_for_destruction)
      end
    end

    def weighings_present
      errors.add(:weighings, :blank) if kept_weighings.empty?
    end

    def recalculate?(side)
      return false if side == "destination" && !destination_entered?

      new_record? || INPUTS.any? { |input| will_save_change_to_attribute?("#{side}_#{input}") } || will_save_change_to_coffee_state?
    end

    # Cherry uses the yield; parchment, humidity and damage (empty damage
    # is 0 %, as in the purchases).
    def clear_unused_inputs
      SIDES.each do |side|
        next if side == "destination" && !destination_entered?

        if cherry?
          self["#{side}_humidity_percent"] = self["#{side}_damage_percent"] = nil
        else
          self["#{side}_damage_percent"] ||= 0
          self["#{side}_yield_factor"] = nil
        end
      end
    end

    def calculate(side)
      gross = self["#{side}_gross_weight"]
      sacks = self["#{side}_sacks"]
      inputs = cherry? ? [ self["#{side}_yield_factor"] ] : [ self["#{side}_humidity_percent"], self["#{side}_damage_percent"] ]
      return unless gross.present? && sacks.present? && inputs.all?(&:present?)

      calculation = PurchaseCalculation.new(coffee_state:, gross_weight: gross, price_per_pound: 0,
                                            humidity_percent: self["#{side}_humidity_percent"],
                                            damage_percent: self["#{side}_damage_percent"],
                                            yield_factor: self["#{side}_yield_factor"], counted_sacks: sacks)
      self["#{side}_tare"] = calculation.tare
      self["#{side}_net_weight"] = calculation.net_weight
    end

    def inputs_of_origin
      side_inputs("origin")
    end

    def destination_complete
      errors.add(:received_on, :blank) if received_on.blank?
      errors.add(:destination_gross_weight, :blank) if destination_gross_weight.blank?
      errors.add(:destination_sacks, :blank) if destination_sacks.blank?
      if destination_gross_weight.present? && !(destination_gross_weight.positive? && destination_gross_weight < MAX_WEIGHT)
        errors.add(:destination_gross_weight, :invalid)
      end
      if destination_sacks.present? && !(destination_sacks.positive? && destination_sacks < MAX_SACKS)
        errors.add(:destination_sacks, :invalid)
      end
      side_inputs("destination")
    end

    def side_inputs(side)
      if cherry?
        value = self["#{side}_yield_factor"]
        errors.add(:"#{side}_yield_factor", :invalid) unless value.present? && value.positive? && value <= 1
      else
        %w[humidity_percent damage_percent].each do |input|
          value = self["#{side}_#{input}"]
          errors.add(:"#{side}_#{input}", :invalid) unless value.present? && value >= 0 && value < 100
        end
      end
    end

    def received_after_departure
      return unless received_on && departed_at

      errors.add(:received_on, :before_departure) if received_on < departed_at.in_time_zone.to_date
    end

    def buyer_active
      errors.add(:buyer, :inactive) if buyer && !buyer.active?
    end

    def carrier_and_truck_active
      errors.add(:carrier, :inactive) if will_save_change_to_carrier_id? && carrier && !carrier.active?
      errors.add(:truck, :inactive) if will_save_change_to_truck_id? && truck && !truck.active?
    end

    # In a sale its weights and buyer are what was charged.
    def not_sold
      return unless sold?

      changed_inputs = (changed - %w[updated_at lock_version observations remission_number carrier_id truck_id driver_id driver_name trip_price weight_note_number])
      errors.add(:base, :sold) if changed_inputs.any?
    end

    def assign_season
      self.season_year = Season.for(departed_at.in_time_zone.to_date).year if departed_at
    end

    # A carrier or a driver, never both (client, 2026-10-30); the trip price
    # goes with the carrier.
    def keep_one_transport
      if transport_mode == "driver"
        self.carrier = nil
      else
        self.driver = nil
        self.driver_name = nil
      end
      self.trip_price = nil unless carrier
    end

    def carrier_or_driver
      errors.add(:base, :carrier_and_driver) if carrier_id && (driver_id || driver_name.present?)
    end

    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end

    def warehouse_active
      errors.add(:warehouse, :inactive) if warehouse && !warehouse.active?
    end
end
