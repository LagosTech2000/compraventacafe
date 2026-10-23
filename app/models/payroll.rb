# A payroll ("planilla") of a farm: who works it, what they worked and what
# they were paid, plus its expenses, so it keeps its own accounts.
#
# Kinds (decided by the owner, 2026-10-10):
#   daily    paid by day worked (attendance: full or half day) × daily wage;
#            the wage comes from the member's role or a wage of their own
#   task     ("por obra") each task has a value split in equal parts among
#            the members who did it; paid in the period it was completed
#   harvest  coffee picking: paid by cans picked × the payroll's can price;
#            its foremen ("caporales", members with a role or wage of their
#            own) do not pick: they are paid by day like a daily payroll
#
# Every kind is paid by pay period (PayPeriod): weekly, biweekly or monthly.
class Payroll < ApplicationRecord
  include Auditable

  KINDS = %w[daily task harvest].freeze
  # Not started yet ("upcoming"), running ("active") or past its end date.
  STATUSES = %w[active upcoming finished].freeze
  MAX_AMOUNT = 10_000_000

  belongs_to :farm
  belongs_to :created_by, class_name: "User"
  has_many :roles, -> { order(:name) }, class_name: "PayrollRole", dependent: :restrict_with_error
  has_many :members, class_name: "PayrollMember", dependent: :restrict_with_error
  has_many :tasks, class_name: "PayrollTask", dependent: :restrict_with_error
  has_many :payments, class_name: "PayrollPayment", dependent: :restrict_with_error
  has_many :expenses, class_name: "PayrollExpense", dependent: :restrict_with_error
  has_many :attendances, through: :members
  has_many :harvest_entries, through: :members
  has_many :overtimes, through: :members

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 100 }
  validates :kind, inclusion: { in: KINDS }
  validates :pay_frequency, inclusion: { in: PayPeriod::FREQUENCIES }
  validates :starts_on, presence: true
  validates :can_price, numericality: { greater_than: 0, less_than: 100_000 }, if: :harvest?
  # What an extra hour is worth (Fernando, 2026-10-14): optional; extra
  # hours can be written only once it is set. Not for payrolls by task.
  validates :overtime_hour_rate, numericality: { greater_than: 0, less_than: 100_000 }, allow_nil: true
  validates :observations, length: { maximum: 500 }
  validate :ends_after_start
  validate :periods_fixed_once_paid, on: :update

  before_validation { self.can_price = nil unless harvest? }
  before_validation { self.overtime_hour_rate = nil if task? }

  scope :newest_first, -> { order(starts_on: :desc, id: :desc) }
  scope :active, ->(today = Time.zone.today) { where(starts_on: ..today).where("ends_on IS NULL OR ends_on >= ?", today) }
  scope :upcoming, ->(today = Time.zone.today) { where(starts_on: (today + 1)..) }
  scope :finished, ->(today = Time.zone.today) { where(ends_on: ...today) }
  # Running or about to start: what is still being worked on.
  scope :unfinished, ->(today = Time.zone.today) { where("payrolls.ends_on IS NULL OR payrolls.ends_on >= ?", today) }

  def audit_label
    "#{name} · #{farm&.name}"
  end

  KINDS.each { |value| define_method(:"#{value}?") { kind == value } }

  def human_kind = self.class.human_attribute_name("kind/#{kind}")
  def human_pay_frequency = self.class.human_attribute_name("pay_frequency/#{pay_frequency}")

  def status(today = Time.zone.today)
    return "upcoming" if starts_on > today

    ends_on && ends_on < today ? "finished" : "active"
  end

  def human_status = self.class.human_attribute_name("status/#{status}")

  # Periods that have started, oldest first.
  def periods(through: Time.zone.today)
    PayPeriod.for(self, through:)
  end

  def period_containing(date)
    PayPeriod.containing(self, date)
  end

  def payment_for(period)
    payments.detect { |payment| payment.period_starts_on == period.starts_on }
  end

  # A paid period cannot change: what was worked in it is closed.
  def paid_on?(date)
    payments.where(period_starts_on: ..date, period_ends_on: date..).exists?
  end

  # Members that appear in the timesheet of a period: the active ones, and
  # inactive ones with something recorded in it.
  def members_for(period)
    days = attendances.where(worked_on: period.dates).select(:payroll_member_id)
    cans = harvest_entries.where(worked_on: period.dates).select(:payroll_member_id)
    extra = overtimes.where(period_starts_on: period.starts_on).select(:payroll_member_id)
    members.where(active: true).or(members.where(id: days)).or(members.where(id: cans)).or(members.where(id: extra))
           .includes(:person, :role).sort_by(&:sort_key)
  end

  def calculation(period)
    PayrollCalculation.new(self, period)
  end

  # A period with its payment (if paid) and what it amounts to: the payment's
  # total once paid, what has been recorded so far otherwise.
  PeriodRow = Struct.new(:period, :payment, :gross_total) do
    def paid? = payment.present?

    def status(today = Time.zone.today)
      return "paid" if paid?
      return "upcoming" if period.starts_on > today

      period.due?(today) ? "to_pay" : "in_progress"
    end
  end

  # Every period up to the payroll's end, newest first: the ones not started
  # yet show as upcoming. Without an end date, only the next one is shown.
  def period_rows(today = Time.zone.today)
    paid = payments.index_by(&:period_starts_on)
    started = periods(through: today)
    horizon = ends_on || (started.last ? started.last.ends_on + 1 : starts_on)
    periods(through: [ horizon, today ].max).reverse.map do |period|
      payment = paid[period.starts_on]
      gross_total = if payment then payment.gross_total
      elsif period.starts_on > today then 0
      else calculation(period).gross_total
      end
      PeriodRow.new(period, payment, gross_total)
    end
  end

  # Periods due (their last day has come) and not paid yet, with something to pay.
  def periods_to_pay(today = Time.zone.today)
    paid = payments.map(&:period_starts_on)
    due = periods(through: today).select { |period| period.due?(today) && paid.exclude?(period.starts_on) }
    return [] if due.empty?

    # Only periods with something recorded can have something to pay: one
    # look at the dates first, instead of a calculation per period (the home
    # page and the pending work read every payroll).
    recorded = dates_with_work(due.first.starts_on..due.last.ends_on)
    due.select { |period| recorded.any? { |date| period.dates.cover?(date) } && calculation(period).gross_total.positive? }
  end

  # The payroll's accounts: what was paid (gross: what the members earned,
  # including what went to their loans) plus expenses.
  def gross_paid = payments.sum(:gross_total)
  def loans_paid = payments.sum(:loans_total)
  def net_paid = payments.sum(:net_total)
  def expenses_total = expenses.sum(:amount)
  def total_cost = gross_paid + expenses_total

  private
    # The days with work recorded in a range (attendance, cans, tasks done)
    # and the first days of the periods with overtime.
    def dates_with_work(range)
      dates = case kind
      when "task" then tasks.where(completed_on: range).distinct.pluck(:completed_on)
      when "harvest" then harvest_entries.where(worked_on: range).distinct.pluck(:worked_on) | attendances.where(worked_on: range).distinct.pluck(:worked_on)
      else attendances.where(worked_on: range).distinct.pluck(:worked_on)
      end
      kind == "task" ? dates : dates | overtimes.where(period_starts_on: range).distinct.pluck(:period_starts_on)
    end

    def ends_after_start
      errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
    end

    # The kind cannot change once paid, and the dates cannot leave out a paid
    # period or work already recorded. Frequency and dates can change: the
    # periods not paid yet follow them (see PayPeriod).
    def periods_fixed_once_paid
      errors.add(:kind, :fixed_once_paid) if will_save_change_to_kind? && payments.exists?
      # Only daily payrolls take a person in several roles.
      errors.add(:kind, :repeated_people) if will_save_change_to_kind? && !daily? &&
                                             members.group(:person_id).having("COUNT(*) > 1").exists?
      first_day, last_day = recorded_dates.minmax
      errors.add(:starts_on, :after_recorded, date: I18n.l(first_day)) if starts_on && first_day && starts_on > first_day
      errors.add(:ends_on, :before_recorded, date: I18n.l(last_day)) if ends_on && last_day && ends_on < last_day
    end

    # Days with something recorded: paid periods, attendance, cans, tasks.
    def recorded_dates
      [ payments.minimum(:period_starts_on), payments.maximum(:period_ends_on),
        attendances.minimum(:worked_on), attendances.maximum(:worked_on),
        harvest_entries.minimum(:worked_on), harvest_entries.maximum(:worked_on),
        tasks.minimum(:completed_on), tasks.maximum(:completed_on) ].compact
    end
end
