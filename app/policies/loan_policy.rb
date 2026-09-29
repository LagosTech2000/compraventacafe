# A loan with payments is frozen: its payments were split with its terms.
class LoanPolicy < ApplicationPolicy
  self.module_key = "loans"

  def update?
    super && !with_payments?
  end

  def destroy?
    super && !with_payments?
  end

  private
    def with_payments?
      record.is_a?(Loan) && record.payments.exists?
    end
end
