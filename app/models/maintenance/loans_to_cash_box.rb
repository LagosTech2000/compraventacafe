module Maintenance
  # loans:to_cash_box — the loans' account goes away (Fernando, 2026-11-23:
  # «los préstamos en efectivo salen de la caja principal … no quieren
  # tener las cuentas en negativo»): what it had moves to where the money
  # really moved. The cash of the loans since the cash box's opening day,
  # and the payments in money, to the cash box (the account suggested for
  # cash); the loans from before its opening (the portfolio loaded in bulk:
  # that money left before the system) and the payments with coffee (no
  # money moved: the invoice paid less) without an account. The loans'
  # account stops being it and is deactivated. Audited by its models;
  # undone what nobody changed since. The cash box then needs a real count.
  class LoansToCashBox < Task
    self.key = "loans:to_cash_box"
    self.tier = :fill
    self.area = :finance

    def sections
      return [ section(t(:title_section), "ok", [ t(:none) ]) ] unless account

      plan = self.plan
      lines = [
        t(:from_account, account: account.name, balance: money(AccountBalance.new.for(account))),
        t(:to_box, box: box&.name || t(:no_box), date: box ? day(box.opening_on) : "—"),
        t(:loans_box, count: plan[:loans_box].size, amount: money(Loan.where(id: plan[:loans_box]).sum(:cash_amount))),
        t(:loans_none, count: plan[:loans_none].size, amount: money(Loan.where(id: plan[:loans_none]).sum(:cash_amount))),
        t(:payments_box, count: plan[:payments_box].size, amount: money(LoanPayment.where(id: plan[:payments_box]).sum(:amount))),
        t(:payments_none, count: plan[:payments_none].size, amount: money(LoanPayment.where(id: plan[:payments_none]).sum(:amount)))
      ]
      lines << t(:box_after, box: box.name, balance: money(box_after)) if box
      [ section(t(:title_section), box ? "warn" : "bad", lines) ]
    end

    def apply!
      raise ActiveRecord::RecordNotFound, "no cash box" unless account && box

      plan = self.plan
      moved = { "loans" => [], "payments" => [] }
      { loans_box: box.id, loans_none: nil }.each do |part, target|
        Loan.lock.where(id: plan[part]).find_each do |loan|
          moved["loans"] << [ loan.id, loan.money_account_id, target ]
          loan.money_account_id = target
          # The portfolio from before the cash box moved no money in the system.
          loan.outside_cash = target.nil?
          loan.save!(validate: false)
        end
      end
      { payments_box: box.id, payments_none: nil }.each do |part, target|
        LoanPayment.lock.where(id: plan[part]).find_each do |payment|
          moved["payments"] << [ payment.id, payment.money_account_id, target ]
          payment.money_account_id = target
          payment.save!(validate: false)
        end
      end
      moved["account"] = [ account.id, account.default_for, account.active ]
      account.default_for = account.default_for - [ MoneyAccount::LOANS ]
      account.active = false
      account.save!(validate: false)
      moved
    end

    def sections_after_apply(changes)
      [ section(t(:title_section), "ok", [ t(:done, loans: changes["loans"].size, payments: changes["payments"].size) ]) ]
    end

    def self.revert!(changes)
      count = 0
      { Loan => changes["loans"], LoanPayment => changes["payments"] }.each do |model, rows|
        rows.each do |id, before, after|
          record = model.lock.find_by(id:)
          next unless record && record.money_account_id == after

          record.money_account_id = before
          record.outside_cash = false if record.is_a?(Loan)
          record.save!(validate: false)
          count += 1
        end
      end
      id, default_for, active = changes["account"]
      if (account = MoneyAccount.find_by(id:))
        account.default_for = default_for
        account.active = active
        account.save!(validate: false)
      end
      count
    end

    private
      def account = @account ||= MoneyAccount.where("? = ANY(default_for)", MoneyAccount::LOANS).first
      def box = @box ||= MoneyAccount.active.where.not(id: account&.id).where("? = ANY(default_for)", "cash").order(:id).first

      def plan
        @plan ||= begin
          loans = Loan.where(money_account_id: account.id)
          payments = LoanPayment.where(money_account_id: account.id)
          opening = box&.opening_on || Date.new(1900, 1, 1)
          { loans_box: loans.where(disbursed_on: opening..).ids, loans_none: loans.where(disbursed_on: ...opening).ids,
            payments_box: payments.where(payment_method: LoanPayment::PAYMENT_METHODS).ids,
            payments_none: payments.where.not(payment_method: LoanPayment::PAYMENT_METHODS).ids }
        end
      end

      # The cash box after the move (before its new count).
      def box_after
        AccountBalance.new.for(box) - Loan.where(id: plan[:loans_box]).sum(:cash_amount) + LoanPayment.where(id: plan[:payments_box]).sum(:amount)
      end
  end
end
