# Coffee bought from a producer: its weight (in one figure or by weighings),
# the calculation from it and where it is in its lifecycle.
class Purchase < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :trading, :sales

  COFFEE_STATES = %w[cherry wet_parchment dry_parchment].freeze
  # The gross weight is typed in one figure, or is the sum of weighings
  # (PurchaseWeighing), each with the sacks counted on the scale.
  WEIGHT_MODES = %w[single weighings].freeze
  # Kinds of damage of a parchment purchase with damage above 0: at least
  # one (Fernando, 2026-10-24).
  DAMAGE_TYPES = %w[yellow borer green pulp peeled].freeze
  # What the calculation reads. Results are recalculated only when one of
  # these changes, so a stored purchase keeps its numbers if the rule changes.
  # By weighings, the counted sacks are an input too.
  CALCULATION_INPUTS = %w[coffee_state weight_mode gross_weight humidity_percent damage_percent yield_factor price_per_pound].freeze

  belongs_to :producer
  belongs_to :zone, optional: true
  # Optional: one of its producer's farms.
  belongs_to :farm, optional: true
  # Optional: the carrero who hauled it (Hauler). Their commission is
  # calculated with their price per pound of that moment, kept here.
  belongs_to :hauler, optional: true
  belongs_to :invoice, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :voided_by, class_name: "User", optional: true
  # Loan payments made with this purchase's money ("pago con café").
  has_many :loan_payments, dependent: :restrict_with_error
  has_many :weighings, -> { order(:id) }, class_name: "PurchaseWeighing", dependent: :destroy, inverse_of: :purchase
  accepts_nested_attributes_for :weighings, allow_destroy: true, reject_if: :blank_weighing?

  normalizes :observations, with: FieldFormats::STRIP

  validates :purchased_at, presence: true
  validates :coffee_state, inclusion: { in: COFFEE_STATES }
  validates :weight_mode, inclusion: { in: WEIGHT_MODES }
  validate :weighings_present, if: :by_weighings?
  validates :gross_weight, numericality: { greater_than: 0, less_than: 100_000 }
  validates :price_per_pound, numericality: { greater_than: 0, less_than: 100_000 }
  with_options if: :recalculate? do
    with_options unless: :cherry? do
      validates :humidity_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
      validates :damage_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
    end
    validates :yield_factor, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, if: :cherry?
  end
  validates :observations, length: { maximum: 500 }
  validate :invoice_belongs_to_same_producer
  validate :farm_belongs_to_producer
  validate :voided_not_invoiced
  validate :hauler_active, if: :will_save_change_to_hauler_id?
  validate :hauler_commission_not_paid_out
  validate :damage_types_chosen, if: -> { new_record? || will_save_change_to_damage_percent? || will_save_change_to_damage_types? }

  # First: by weighings, the gross weight and sacks come from them.
  before_validation :sum_weighings
  before_validation :clear_unused_inputs, if: :recalculate?
  before_validation :calculate, if: :recalculate?
  before_validation :assign_season
  before_validation :settle_damage_types
  # After the calculation: it needs the net weight.
  before_validation :apply_hauler_commission

  before_destroy :ensure_hauler_commission_not_paid_out
  # A producer without a zone takes the zone of the purchase registered for
  # them (Fernando, 2026-10-18). Same transaction, audited as the person's
  # change. A zone the producer already has is never replaced.
  after_create :give_zone_to_producer

  # Purchases of a day (or a range of days), in Tegucigalpa time.
  scope :on, ->(dates) { where(purchased_at: day_range(dates)) }
  scope :active, -> { where(voided_at: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  # Waiting to be invoiced: neither invoiced nor voided.
  scope :uninvoiced, -> { active.where(invoice_id: nil) }
  scope :in_season, ->(season) { where(season_year: season.year) }
  # Most recent purchase first; same moment, last registered first.
  scope :newest_first, -> { order(purchased_at: :desc, id: :desc) }

  # The zone given to the producer when this purchase was saved, if any.
  attr_reader :zone_given_to_producer

  # A date, or a range of dates with open ends, as a range of moments.
  def self.day_range(dates)
    dates = dates..dates unless dates.is_a?(Range)
    (dates.begin&.in_time_zone&.beginning_of_day)..(dates.end&.in_time_zone&.end_of_day)
  end

  # The id is shown next to it in the audit log; the producer names it.
  def audit_label
    producer.full_name
  end

  def invoiced?
    invoice_id.present?
  end

  def voided?
    voided_at.present?
  end

  def cherry?
    coffee_state == "cherry"
  end

  def by_weighings?
    weight_mode == "weighings"
  end

  # Weighings that stay after saving (the form may mark some for removal).
  def kept_weighings
    weighings.reject(&:marked_for_destruction?)
  end

  def season
    Season.new(season_year) if season_year
  end

  # QQ: the net weight in quintals of 125 lb.
  def quintals
    PurchaseCalculation.quintals(net_weight) if net_weight
  end

  def damaged? = !cherry? && damage_percent.to_d.positive?

  # "Amarillo, Broca".
  def human_damage_types
    damage_types.map { self.class.human_attribute_name("damage_types/#{it}") }.join(", ").presence
  end

  def human_coffee_state
    self.class.human_attribute_name("coffee_state/#{coffee_state}")
  end

  def loan_payments_total
    loan_payments.sum(&:amount)
  end

  # What the producer is paid: the purchase minus the loan payments it made.
  def amount_to_pay
    total - loan_payments_total
  end

  # Counted in the database, so payments saved a moment ago are included.
  # Once its invoice has payments, the loans can only take what the invoice
  # still owes: what was already paid out cannot go to a loan.
  def available_for_loans
    left = total - loan_payments.sum(:amount)
    return left unless invoice

    paid = invoice.payments.sum(:amount)
    [ left, invoice.amount_to_pay - paid ].min
  end

  # Its money can still go to a loan: not voided, not yet paid out, and
  # something left.
  def accepts_loan_payments?
    persisted? && !voided? && !invoice&.paid? && available_for_loans.positive?
  end

  # Takes the purchase out of every list and total without deleting it.
  def void!(user)
    update!(voided_at: Time.current, voided_by: user)
  end

  private
    def recalculate?
      inputs = by_weighings? ? CALCULATION_INPUTS + %w[sacks] : CALCULATION_INPUTS
      new_record? || inputs.any? { |input| will_save_change_to_attribute?(input) }
    end

    def blank_weighing?(attributes)
      attributes["id"].blank? && attributes.values_at("gross_weight", "sacks").all?(&:blank?)
    end

    # By weighings, the gross weight and the sacks are their sums (never
    # typed). Switched back to one figure, its old weighings are removed.
    def sum_weighings
      if by_weighings?
        kept = kept_weighings
        self.gross_weight = kept.sum { |weighing| weighing.gross_weight.to_d }
        self.sacks = kept.sum { |weighing| weighing.sacks.to_i }
      elsif will_save_change_to_weight_mode?
        weighings.each(&:mark_for_destruction)
      end
    end

    # Only with damage; the known kinds, once each.
    def settle_damage_types
      self.damage_types = damaged? ? Array(damage_types).compact_blank.uniq & DAMAGE_TYPES : []
    end

    def damage_types_chosen
      errors.add(:damage_types, :choose_at_least_one) if damaged? && damage_types.empty?
    end

    def weighings_present
      errors.add(:weighings, :blank) if kept_weighings.empty?
    end

    # Cherry has no humidity nor damage; parchment has no yield. Parchment
    # with the damage left empty has no damage (0 %, its default).
    def clear_unused_inputs
      if cherry?
        self.humidity_percent = nil
        self.damage_percent = nil
      else
        self.damage_percent ||= 0
        self.yield_factor = nil
      end
    end

    def calculate
      inputs = cherry? ? [ yield_factor ] : [ humidity_percent, damage_percent ]
      return unless gross_weight.present? && price_per_pound.present? && inputs.all?(&:present?)

      calculation = PurchaseCalculation.new(coffee_state:, gross_weight:, price_per_pound:,
                                            humidity_percent:, damage_percent:, yield_factor:,
                                            counted_sacks: (sacks if by_weighings?))
      self.sacks = calculation.sacks
      self.tare = calculation.tare
      self.net_weight = calculation.net_weight
      self.damage_weight = calculation.damage_weight
      self.damage_amount = calculation.damage_amount
      self.total = calculation.total
    end

    # Chosen (or changed), the hauler's price per pound of now is kept; the
    # commission follows the net weight with it. A purchase from before
    # 2026-10-24 keeps its cans, can price and percent. Without a hauler,
    # nothing.
    def apply_hauler_commission
      if hauler.nil?
        self.hauler_price_per_pound = self.hauler_commission_percent = self.hauler_can_price = self.hauler_cans = self.hauler_commission = nil
        return
      end
      if new_record? || will_save_change_to_hauler_id?
        self.hauler_price_per_pound = hauler.price_per_pound
        self.hauler_commission_percent = self.hauler_can_price = self.hauler_cans = nil
      end
      return unless net_weight && (new_record? || will_save_change_to_hauler_id? || will_save_change_to_net_weight? || hauler_commission.nil?)

      if hauler_price_per_pound
        self.hauler_commission = Hauler.commission(net_weight:, price_per_pound: hauler_price_per_pound)
      else
        self.hauler_cans, self.hauler_commission = Hauler.can_commission(net_weight:, percent: hauler_commission_percent, can_price: hauler_can_price)
      end
    end

    def hauler_active
      errors.add(:hauler, :inactive) if hauler && !hauler.active?
    end

    # What a hauler was already paid stays covered: a change that lowers
    # their commissions (voiding, another hauler, less weight) cannot leave
    # them owing the business.
    def hauler_commission_not_paid_out(destroying: false)
      return unless destroying || will_save_change_to_hauler_id? || will_save_change_to_hauler_commission? || will_save_change_to_voided_at?

      [ hauler_id_in_database, hauler_id ].compact.uniq.each do |id|
        before = hauler_id_in_database == id && voided_at_in_database.nil? ? hauler_commission_in_database.to_d : 0
        after = !destroying && hauler_id == id && voided_at.nil? ? hauler_commission.to_d : 0
        next if after >= before

        paid_to = Hauler.find(id)
        errors.add(:base, :hauler_paid, hauler: paid_to.full_name) if paid_to.balance - before + after < 0
      end
    end

    def ensure_hauler_commission_not_paid_out
      hauler_commission_not_paid_out(destroying: true)
      throw :abort if errors.any?
    end

    def assign_season
      self.season_year = Season.for(purchased_at.to_date).year if purchased_at
    end

    def give_zone_to_producer
      person = producer&.person
      return unless zone && person && person.zone_id.nil?

      # Only the zone changes: details the person was saved without (older
      # rules) do not stop the purchase.
      person.zone = zone
      person.save!(validate: false)
      @zone_given_to_producer = zone
    end

    def farm_belongs_to_producer
      errors.add(:farm, :other_producer) if farm && farm.producer_id != producer_id
    end

    def invoice_belongs_to_same_producer
      return if invoice.nil? || invoice.producer_id == producer_id

      errors.add(:invoice, :other_producer)
    end

    def voided_not_invoiced
      errors.add(:base, :voided_invoiced) if voided? && invoiced?
    end
end
