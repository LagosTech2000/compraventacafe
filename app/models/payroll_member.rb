# A person (with the collaborator role) working a payroll. In a daily
# payroll the daily wage is their own one if set, otherwise their role's.
# In a harvest payroll the foremen ("caporales") do not pick coffee: a
# member with a role or a wage of their own is paid by day like in a daily
# payroll; the rest are paid by cans.
# A member with work recorded is deactivated, never removed.
class PayrollMember < ApplicationRecord
  include Auditable

  belongs_to :payroll
  belongs_to :person
  belongs_to :role, class_name: "PayrollRole", foreign_key: :payroll_role_id, optional: true, inverse_of: :members
  has_many :attendances, class_name: "PayrollAttendance", dependent: :restrict_with_error
  has_many :harvest_entries, dependent: :restrict_with_error
  has_many :overtimes, class_name: "PayrollOvertime", dependent: :restrict_with_error, inverse_of: :member
  has_many :task_participations, class_name: "PayrollTaskParticipant", dependent: :restrict_with_error
  has_many :payment_lines, class_name: "PayrollPaymentLine", dependent: :restrict_with_error

  validates :person_id, uniqueness: { scope: :payroll_id }
  validates :daily_wage_override, numericality: { greater_than: 0, less_than: 100_000 }, allow_nil: true
  validate :person_is_collaborator, :role_of_same_payroll
  validate :has_daily_wage, if: -> { payroll&.daily? }
  validate :basis_fits_work, on: :update, if: -> { payroll&.harvest? }

  scope :active, -> { where(active: true) }

  def audit_label
    "#{person&.full_name} · #{payroll&.audit_label}"
  end

  def full_name = person.full_name

  # Own wage first; otherwise the role's.
  def daily_wage
    daily_wage_override || role&.daily_wage
  end

  def own_wage? = daily_wage_override.present?

  # Paid by days worked (attendance) instead of cans or tasks.
  def paid_by_day?
    payroll.daily? || (payroll.harvest? && daily_wage.present?)
  end

  # How this member's pay is counted: "daily", "harvest" (cans) or "task".
  def basis = paid_by_day? ? "daily" : payroll.kind

  def sort_key = [ person.last_names.downcase, person.first_names.downcase ]

  private
    def person_is_collaborator
      errors.add(:person, :not_collaborator) if person && !person.collaborator?
    end

    def role_of_same_payroll
      errors.add(:role, :other_payroll) if role && role.payroll_id != payroll_id
    end

    # A picker with cans cannot become a foreman, nor the other way round.
    def basis_fits_work
      if paid_by_day? && harvest_entries.exists?
        errors.add(:base, :has_cans)
      elsif !paid_by_day? && attendances.exists?
        errors.add(:base, :has_attendance)
      end
    end

    def has_daily_wage
      errors.add(:base, :no_daily_wage) if daily_wage.nil?
    end
end
