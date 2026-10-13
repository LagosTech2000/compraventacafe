# Money lent to a person (any person: client, collaborator, producer...),
# with simple interest at a monthly rate chosen for each loan. See
# LoanBalance for how interest and payments work.
#
# A loan can be cash, supplies (fertilizer...) or both: its principal is the
# cash plus the value of its supply lines, and interest runs on all of it.
class Loan < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :loans

  STATUSES = %w[active overdue paid_off].freeze
  KINDS = %w[cash supplies mixed].freeze
  MAX_AMOUNT = 10_000_000

  belongs_to :person
  belongs_to :created_by, class_name: "User"
  has_many :payments, class_name: "LoanPayment", dependent: :restrict_with_error
  has_many :supply_items, class_name: "LoanSupply", dependent: :destroy, inverse_of: :loan
  accepts_nested_attributes_for :supply_items, allow_destroy: true, reject_if: :blank_supply_item?

  normalizes :observations, with: FieldFormats::STRIP

  validates :cash_amount, numericality: { greater_than_or_equal_to: 0, less_than: MAX_AMOUNT }
  validates :principal, numericality: { less_than: MAX_AMOUNT }
  validate :something_lent
  validates :monthly_interest_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :disbursed_on, :due_on, presence: true
  validates :observations, length: { maximum: 500 }
  validate :due_on_not_before_disbursement

  before_validation :compute_principal

  scope :newest_first, -> { order(disbursed_on: :desc, id: :desc) }
  scope :paid_off, -> { where.not(paid_off_on: nil) }
  scope :unpaid, -> { where(paid_off_on: nil) }
  scope :overdue, -> { unpaid.where(due_on: ...Time.zone.today) }
  scope :active, -> { unpaid.where(due_on: Time.zone.today..) }
  scope :with_status, ->(status) { public_send(status) if STATUSES.include?(status) }
  scope :with_supplies, -> { where(id: LoanSupply.select(:loan_id)) }
  scope :without_supplies, -> { where.not(id: LoanSupply.select(:loan_id)) }
  scope :of_kind, lambda { |kind|
    case kind
    when "cash" then without_supplies
    when "supplies" then with_supplies.where(cash_amount: 0)
    when "mixed" then with_supplies.where(cash_amount: 0.01..)
    else all
    end
  }

  def audit_label
    "#{self.class.model_name.human} #{id} · #{person.full_name}"
  end

  # Days from the loan's date to its due date.
  def term_days
    (due_on - disbursed_on).to_i if due_on && disbursed_on
  end

  def paid_off?
    paid_off_on.present?
  end

  # Supply lines that stay after saving (the form may mark some for removal).
  def kept_supply_items
    supply_items.reject(&:marked_for_destruction?)
  end

  def supplies_amount
    kept_supply_items.sum { |item| LoanSupply.total_for(item.quantity, item.unit_price) || 0 }
  end

  # Cash only, supplies only, or both.
  def kind
    return "cash" if kept_supply_items.empty?

    cash_amount.to_d.positive? ? "mixed" : "supplies"
  end

  def human_kind
    self.class.human_attribute_name("kind/#{kind}")
  end

  def overdue?(today = Time.zone.today)
    !paid_off? && due_on < today
  end

  def paid_on_time?
    paid_off? && paid_off_on <= due_on
  end

  def status
    return "paid_off" if paid_off?

    overdue? ? "overdue" : "active"
  end

  def human_status
    self.class.human_attribute_name("status/#{status}")
  end

  # Uses the payments already loaded (lists preload them) instead of querying.
  def balance(as_of: Time.zone.today)
    ordered = payments.loaded? ? payments.sort_by { |payment| [ payment.paid_on, payment.id ] } : payments.chronological
    LoanBalance.new(self, as_of:, payments: ordered)
  end

  private
    def blank_supply_item?(attributes)
      attributes["id"].blank? && attributes.values_at("supply_id", "quantity").all?(&:blank?)
    end

    # The principal is never typed: it is the cash plus the supplies. Cash
    # left blank (supplies only) is 0.
    def compute_principal
      self.cash_amount = 0 if cash_amount.nil?
      self.principal = cash_amount.to_d + supplies_amount
    end

    def something_lent
      errors.add(:base, :nothing_lent) unless principal.to_d.positive?
    end

    def due_on_not_before_disbursement
      return unless disbursed_on && due_on && due_on < disbursed_on

      errors.add(:due_on, :before_disbursement)
    end
end
