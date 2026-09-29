# Money lent to a person (any person: client, collaborator, producer...),
# with simple interest at a monthly rate chosen for each loan. See
# LoanBalance for how interest and payments work.
class Loan < ApplicationRecord
  include Auditable

  STATUSES = %w[active overdue paid_off].freeze
  MAX_AMOUNT = 10_000_000

  belongs_to :person
  belongs_to :created_by, class_name: "User"
  has_many :payments, class_name: "LoanPayment", dependent: :restrict_with_error

  normalizes :observations, with: FieldFormats::STRIP

  validates :principal, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  validates :monthly_interest_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :disbursed_on, :due_on, presence: true
  validates :observations, length: { maximum: 500 }
  validate :due_on_not_before_disbursement

  scope :newest_first, -> { order(disbursed_on: :desc, id: :desc) }
  scope :paid_off, -> { where.not(paid_off_on: nil) }
  scope :unpaid, -> { where(paid_off_on: nil) }
  scope :overdue, -> { unpaid.where(due_on: ...Time.zone.today) }
  scope :active, -> { unpaid.where(due_on: Time.zone.today..) }
  scope :with_status, ->(status) { public_send(status) if STATUSES.include?(status) }

  def audit_label
    "#{self.class.model_name.human} #{id} · #{person.full_name}"
  end

  def paid_off?
    paid_off_on.present?
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
    def due_on_not_before_disbursement
      return unless disbursed_on && due_on && due_on < disbursed_on

      errors.add(:due_on, :before_disbursement)
    end
end
