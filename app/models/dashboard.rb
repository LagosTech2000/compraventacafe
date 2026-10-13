# What the home page shows a user: the business at a glance, what needs
# attention, what happened lately and the usual actions, only for the
# modules the user can read. Every figure comes from the records (the same
# scopes and summaries the modules use); nothing is estimated.
class Dashboard
  Figure = Data.define(:key, :value, :hint, :path)
  Pending = Data.define(:key, :count, :amount, :path)
  Activity = Data.define(:at, :kind, :title, :detail, :path)

  # It scrolls inside its panel: more than fit is fine.
  ACTIVITY_SIZE = 15

  attr_reader :user, :today

  def initialize(user, today: Time.zone.today)
    @user = user
    @today = today
  end

  def can?(module_key) = user.can?(module_key, :read)
  def season = Season.for(today)

  def modules = AppModule::KEYS.select { |key| can?(key) }

  # --- Figures ---------------------------------------------------------------

  def today_summary = @today_summary ||= DailyClose.new(today)
  def season_summary = @season_summary ||= PurchaseSummary.new(Purchase.active.in_season(season))

  def open_loans
    @open_loans ||= Loan.unpaid.includes(:person, :payments, :supply_items).to_a
  end

  def loans_owed = @loans_owed ||= open_loans.sum { |loan| loan.balance(as_of: today).total_owed }
  def overdue_loans = @overdue_loans ||= open_loans.select { |loan| loan.overdue?(today) }

  def active_farms_count = Farm.of_business.active.count
  def running_payrolls = @running_payrolls ||= Payroll.active(today).includes(:payments).to_a

  # --- Pending work --------------------------------------------------------------

  def uninvoiced = @uninvoiced ||= PurchaseSummary.new(Purchase.uninvoiced)
  def unpaid_invoices = @unpaid_invoices ||= Invoice.unpaid.includes(:payments, purchases: :loan_payments).to_a

  # Pay periods whose day has come and are not paid, with something to pay.
  def periods_to_pay
    @periods_to_pay ||= Payroll.unfinished(today).includes(:payments).flat_map do |payroll|
      payroll.periods_to_pay(today).map { |period| [ payroll, period ] }
    end
  end

  # Active people of running payrolls paid by day with no wage: their days
  # cannot be paid until they get a role or a wage of their own.
  def members_without_wage
    @members_without_wage ||= PayrollMember.active.where(payroll_role_id: nil, daily_wage_override: nil)
                                           .joins(:payroll).merge(Payroll.unfinished(today)).where(payrolls: { kind: "daily" })
                                           .includes(:payroll).to_a
  end

  # --- Recent activity -----------------------------------------------------------

  # The latest records the user can see, newest first.
  def activity
    @activity ||= begin
      items = []
      items.concat(trading_activity) if can?("trading")
      items.concat(loans_activity) if can?("loans")
      items.concat(farms_activity) if can?("farms")
      items.sort_by { |item| -item.at.to_f }.first(ACTIVITY_SIZE)
    end
  end

  private
    def latest(scope) = scope.order(created_at: :desc).limit(ACTIVITY_SIZE)

    def trading_activity
      latest(Purchase.active.includes(producer: :person)).map do |purchase|
        Activity.new(at: purchase.created_at, kind: :purchase, title: purchase.producer.full_name,
                     detail: { number: purchase.id, quintals: purchase.quintals, total: purchase.total },
                     path: [ :trading_purchase_path, purchase ])
      end +
        latest(Producer.includes(:person)).map do |producer|
          Activity.new(at: producer.created_at, kind: :producer, title: producer.full_name,
                       detail: { kind: producer.human_kind }, path: [ :trading_producer_path, producer ])
        end +
        latest(Invoice.includes(:payments, producer: :person, purchases: :loan_payments)).map do |invoice|
          Activity.new(at: invoice.created_at, kind: :invoice, title: invoice.producer.full_name,
                       detail: { number: invoice.display_number, status: invoice.human_payment_status, total: invoice.amount_to_pay },
                       path: [ :trading_invoice_path, invoice ])
        end
    end

    def loans_activity
      latest(Loan.includes(:person, :supply_items)).map do |loan|
        Activity.new(at: loan.created_at, kind: :loan, title: loan.person.full_name,
                     detail: { number: loan.id, amount: loan.principal }, path: [ :loans_loan_path, loan ])
      end +
        latest(LoanPayment.includes(loan: :person)).map do |payment|
          Activity.new(at: payment.created_at, kind: :loan_payment, title: payment.loan.person.full_name,
                       detail: { number: payment.loan_id, amount: payment.amount }, path: [ :loans_loan_path, payment.loan ])
        end
    end

    def farms_activity
      latest(PayrollPayment.includes(payroll: :farm)).map do |payment|
        Activity.new(at: payment.created_at, kind: :payroll_payment, title: payment.payroll.name,
                     detail: { farm: payment.payroll.farm.name, amount: payment.net_total },
                     path: [ :farms_payroll_payment_path, payment.payroll, payment ])
      end
    end
end
