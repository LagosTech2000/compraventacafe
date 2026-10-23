# Where a loan is (Fernando, 2026-10-18, like a purchase's steps): lent →
# with payments → paid off, from what the loan already keeps (its payments
# and paid_off_on). Being overdue is not a step: the hint says it.
class LoanLifecycle
  include LifecycleSteps

  STAGES = %w[lent repaying paid].freeze

  def self.for(loan)
    if loan.paid_off? then new("paid")
    elsif loan.payments.any? then new("repaying")
    else new("lent")
    end
  end
end
