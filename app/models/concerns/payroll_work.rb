# What a member worked on a day (attendance or cans picked). It must fall
# inside the payroll's dates and in a period not paid yet: a paid period is
# closed.
module PayrollWork
  extend ActiveSupport::Concern

  included do
    belongs_to :member, class_name: "PayrollMember", foreign_key: :payroll_member_id

    validates :worked_on, presence: true, uniqueness: { scope: :payroll_member_id }
    validate :within_payroll, :period_open
    before_destroy :ensure_period_open
  end

  def audit_label
    "#{member&.full_name} · #{worked_on && I18n.l(worked_on)}"
  end

  private
    def payroll = member&.payroll

    def within_payroll
      return unless payroll && worked_on

      errors.add(:worked_on, :outside_payroll) unless payroll.period_containing(worked_on)
    end

    def period_open
      errors.add(:worked_on, :period_paid) if payroll && worked_on && payroll.paid_on?(worked_on_was || worked_on)
    end

    def ensure_period_open
      return unless payroll&.paid_on?(worked_on)

      errors.add(:worked_on, :period_paid)
      throw :abort
    end
end
