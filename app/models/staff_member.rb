# An employee of the business's own payroll (Planilla interna): a person
# with the collaborator role, in one role (StaffRole), from a date. Their
# salary is their own if they have one (Fernando, 2026-10-24: same role,
# different pay), otherwise their role's; the frequency and the overtime
# hour rate are always the role's. Their
# periods follow the role's frequency (PayPeriod, the same as Fincas): paid
# ones stay as they were paid, the next ones follow the role.
#
# Like the client's Excel (Fernando, 2026-10-25), the salary is monthly and
# a period pays salary ÷ 30 × the days worked (StaffAttendance, full or
# half), with a month of 30 days: a period worked whole counts its NOMINAL
# days (15 a fortnight, 30 a month, 7 a week) even when the month has 31 or
# 28; otherwise the days marked, never more than those. Each period is paid
# once, in order (StaffPaymentIssuer), with overtime, the bonuses of the
# goals met and a free bonus, minus the advances given in it. Deactivated,
# never deleted once it has payments or advances.
class StaffMember < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :person
  belongs_to :role, class_name: "StaffRole", foreign_key: :staff_role_id, inverse_of: :members
  has_many :payments, -> { order(:period_starts_on) }, class_name: "StaffPayment", dependent: :restrict_with_error, inverse_of: :member
  has_many :advances, -> { order(:given_on, :id) }, class_name: "StaffAdvance", dependent: :restrict_with_error, inverse_of: :member
  has_many :goals, -> { order(:period_starts_on, :id) }, class_name: "StaffGoal", dependent: :restrict_with_error, inverse_of: :member
  has_many :attendances, -> { order(:worked_on) }, class_name: "StaffAttendance", dependent: :restrict_with_error, inverse_of: :member

  DAYS_PER_MONTH = 30
  # The days a period worked whole counts, by frequency.
  NOMINAL_DAYS = { "weekly" => 7, "biweekly" => 15, "monthly" => 30 }.freeze

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

  def reload(*)
    @attendance_by_date = nil
    super
  end

  # What a period pays: their own salary, or their role's.
  def salary = salary_override || role&.salary
  def own_salary? = salary_override.present?

  def employed_on?(date) = starts_on.present? && date >= starts_on && (ends_on.nil? || date <= ends_on)

  # What a day marked on a date counts (1, 0.5 or 0).
  def day_on(date) = attendance_by_date[date]&.day_fraction || 0.to_d

  # The days that count in some dates, `nominal` at most: all of them for a
  # stretch worked whole (every day of it employed and marked full).
  def days_in(dates, nominal:)
    dates = dates.to_a
    whole = dates.any? && dates.all? { employed_on?(it) && day_on(it) == 1 }
    whole ? nominal.to_d : [ dates.sum(0.to_d) { day_on(it) }, nominal.to_d ].min
  end

  # The days one of its periods counts.
  def period_days(period) = days_in(period.dates, nominal: NOMINAL_DAYS.fetch(pay_frequency))

  # What some days of work earn: monthly salary ÷ 30 × days.
  def earned(days) = salary ? (salary * days / DAYS_PER_MONTH).round(2) : 0.to_d

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

  # Advances given on some dates (taken off or not).
  def advances_in(dates) = advances.select { dates.cover?(it.given_on) }

  # What a period would pay today (StaffPaymentIssuer does it for real).
  def estimate(period) = StaffPaymentIssuer.new(member: self, period:).estimate

  private
    def attendance_by_date = @attendance_by_date ||= attendances.index_by(&:worked_on)

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
