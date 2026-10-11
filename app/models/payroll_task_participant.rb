# A member who took part in a task.
class PayrollTaskParticipant < ApplicationRecord
  include Auditable

  belongs_to :task, class_name: "PayrollTask", foreign_key: :payroll_task_id, inverse_of: :participants
  belongs_to :member, class_name: "PayrollMember", foreign_key: :payroll_member_id

  validates :payroll_member_id, uniqueness: { scope: :payroll_task_id }
  validate :member_of_same_payroll

  def audit_label
    "#{member&.full_name} · #{task&.audit_label}"
  end

  private
    def member_of_same_payroll
      errors.add(:member, :other_payroll) if member && task && member.payroll_id != task.payroll_id
    end
end
