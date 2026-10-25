# An employee of the business's own payroll (Planilla interna): a person
# with the collaborator role, in one role (StaffRole), from a date. Their
# salary is their own if they have one (Fernando, 2026-10-24: same role,
# different pay), otherwise their role's; the frequency and the overtime
# hour rate are always the role's. Their
# periods follow the role's frequency (PayPeriod, the same as Fincas): paid
# ones stay as they were paid, the next ones follow the role. Each period is
# paid once, in order (StaffPaymentIssuer): the role's salary, overtime,
# the bonuses of the goals met and a free bonus, minus the advances given
# in it. Deactivated, never deleted once it has payments or advances.
class StaffMember < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :person
  belongs_to :role, class_name: "StaffRole", foreign_key: :staff_role_id, inverse_of: :members
  has_many :payments, -> { order(:period_starts_on) }, class_name: "StaffPayment", dependent: :restrict_with_error, inverse_of: :member
  has_many :advances, -> { order(:given_on, :id) }, class_name: "StaffAdvance", dependent: :restrict_with_error, inverse_of: :member
  has_many :goals, -> { order(:period_starts_on, :id) }, class_name: "StaffGoal", dependent: :restrict_with_error, inverse_of: :member

  normalizes :observations, with: FieldFormats::STRIP

  validates :person_id, uniqueness: true
  validates :starts_on, presence: true
  validates :salary_override, numericality: { greater_than: 0, less_than: StaffRole::MAX_AMOUNT }, allow_nil: true
  validates :observations, length: { maximum: 500 }
  validate :person_is_collaborator, if: :will_save_change_to_person_id?
  validate :role_active, if: :will_save_change_to_staff_role_id?
  validate :ends_after_start, :keeps_paid_periods

  scope :active, -> { where(active: true) }
  scope :newest_first, -> { joins(:person).merge(Person.alphabetical) }

  delegate :full_name, to: :person
  delegate :pay_frequency, to: :role

  def audit_label = person&.full_name

  # What a period pays: their own salary, or their role's.
  def salary = salary_override || role&.salary
  def own_salary? = salary_override.present?

  # Its periods that have started by `through`, oldest first (PayPeriod);
  # none while its role has no salary.
  def periods(through: Time.zone.today) = role&.priced? ? PayPeriod.for(self, through:) : []

  def paid_period?(period) = payments.any? { it.persisted? && it.period_starts_on == period.starts_on }

  # The periods started and not paid, oldest first.
  def unpaid_periods(through: Time.zone.today) = periods(through:).reject { paid_period?(it) }

  # The next one to pay (they go in order): the oldest not paid, if it started.
  def period_to_pay(today = Time.zone.today) = unpaid_periods(through: today).first

  # Started, not paid and past its payday.
  def due_periods(today = Time.zone.today) = unpaid_periods(through: today).select { it.due?(today) }

  # The period that holds a date (nil before it started or after it ended).
  def period_on(date)
    return if starts_on.nil? || date < starts_on || (ends_on && date > ends_on)

    periods(through: date).last
  end

  # Periods a goal can be set for: the ones not paid, from the current one
  # to about two months ahead.
  def goal_periods(today = Time.zone.today)
    unpaid_periods(through: [ today + 62, ends_on ].compact.min).select { it.ends_on >= today || it == period_to_pay(today) }
  end

  def pending_advances = advances.select { it.staff_payment_id.nil? }

  # What a period would pay today (StaffPaymentIssuer does it for real).
  def estimate(period) = StaffPaymentIssuer.new(member: self, period:).estimate

  private
    def person_is_collaborator
      errors.add(:person, :not_collaborator) if person && !person.collaborator?
    end

    def role_active
      errors.add(:role, :inactive) if role && !role.active?
    end

    def ends_after_start
      errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
    end

    # Its dates cannot leave out a period already paid.
    def keeps_paid_periods
      return unless persisted? && (will_save_change_to_starts_on? || will_save_change_to_ends_on?)

      first = payments.minimum(:period_starts_on)
      last = payments.maximum(:period_ends_on)
      errors.add(:starts_on, :after_paid_period) if first && starts_on && starts_on > first
      errors.add(:ends_on, :before_paid_period) if last && ends_on && ends_on < last
    end
end
