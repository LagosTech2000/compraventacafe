# A task of a payroll paid by task ("por obra"): its value is split in equal
# parts among the members who did it (decided by the owner, 2026-10-10) and
# paid in the pay period of the day it was completed. Once paid, it is
# closed.
class PayrollTask < ApplicationRecord
  include Auditable

  belongs_to :payroll
  has_many :participants, class_name: "PayrollTaskParticipant", dependent: :destroy, inverse_of: :task
  has_many :members, through: :participants

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 150 }
  validates :amount, numericality: { greater_than: 0, less_than: Payroll::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate :completed_within_payroll, :has_participants_when_completed, :not_paid

  before_destroy :ensure_not_paid

  scope :newest_first, -> { order(Arel.sql("completed_on DESC NULLS FIRST"), id: :desc) }
  scope :completed, -> { where.not(completed_on: nil) }
  scope :pending, -> { where(completed_on: nil) }

  def audit_label
    "#{name} · #{payroll&.audit_label}"
  end

  def completed? = completed_on.present?

  def paid?
    completed_on_in_database.present? && payroll.paid_on?(completed_on_in_database)
  end

  # Equal parts, to the cent; the cents left over go one each to the first
  # members (by name), so the parts add up to the value exactly.
  def shares
    ordered = participants.map(&:member).sort_by(&:sort_key)
    return {} if ordered.empty?

    base = (amount / ordered.size).floor(2)
    extra_cents = ((amount - (base * ordered.size)) * 100).to_i
    ordered.each_with_index.to_h { |member, index| [ member, base + (index < extra_cents ? BigDecimal("0.01") : 0) ] }
  end

  # The member ids from the form's checkboxes.
  def member_ids=(ids)
    wanted = Array(ids).compact_blank.map(&:to_i)
    participants.each { |participant| participant.mark_for_destruction unless wanted.include?(participant.payroll_member_id) }
    (wanted - participants.map(&:payroll_member_id)).each { |id| participants.build(payroll_member_id: id) }
  end

  def kept_participants = participants.reject(&:marked_for_destruction?)

  private
    def completed_within_payroll
      return unless payroll && completed_on

      errors.add(:completed_on, :outside_payroll) unless payroll.period_containing(completed_on)
      errors.add(:completed_on, :period_paid) if !paid? && payroll.paid_on?(completed_on)
    end

    def has_participants_when_completed
      errors.add(:base, :no_participants) if completed? && kept_participants.empty?
    end

    def not_paid
      errors.add(:base, :paid) if persisted? && paid?
    end

    def ensure_not_paid
      return unless paid?

      errors.add(:base, :paid)
      throw :abort
    end
end
