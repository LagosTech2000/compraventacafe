# Pays a pay period of a payroll: stores what each member earned
# (PayrollCalculation) and, from that pay, the loan payments chosen for each
# member ("abonar a préstamos desde la planilla"), all or nothing.
#
#   issuer = PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on:, loan_amounts: { loan_id => amount })
#   issuer.save   # => true and issuer.payment, or false and issuer.errors
#
# Each loan payment is a normal LoanPayment (method "payroll", pointing to
# the person's first payment line): interest first, then principal. What
# goes to a person's loans cannot be more than their pay.
#
# A person working a daily payroll in several roles has one line per role
# (PayrollMember), but their loans are taken once, from what all their
# lines add up to (Fernando, 2026-10-17). Each line keeps the part of the
# deduction that fits in it, first line first, so no line pays below zero.
class PayrollPaymentIssuer
  include ActiveModel::Model

  attr_reader :payroll, :period, :paid_on, :loan_amounts, :observations, :payment, :money_account_id

  def self.model_name = ActiveModel::Name.new(self, nil, "PayrollPaymentIssuer")

  def initialize(payroll:, period:, user:, paid_on: nil, loan_amounts: {}, observations: nil, with_loans: false, money_account_id: nil)
    @payroll = payroll
    @period = period
    @user = user
    @paid_on = parse_date(paid_on) || Time.zone.today
    @loan_amounts = loan_amounts.to_h.transform_keys(&:to_i).transform_values { |value| parse_amount(value) }
    @observations = observations.to_s.strip.presence
    @with_loans = with_loans
    # The account the money was handed out from (Control financiero).
    @money_account_id = money_account_id.presence || MoneyAccount.default_for("cash")&.id
  end

  def calculation
    @calculation ||= payroll.calculation(period)
  end

  delegate :lines, :gross_total, to: :calculation

  # The lines of each person, in the lines' order: [[line, ...], ...].
  def person_lines
    @person_lines ||= lines.group_by { |line| line.member.person_id }.values
  end

  # Unpaid loans of each member's person, the ones due first at the top
  # (only for whoever may register loan payments).
  def open_loans(member)
    return [] unless @with_loans

    @open_loans ||= Loan.unpaid.where(person_id: lines.map { |line| line.member.person_id })
                        .includes(:payments, :supply_items).order(:due_on, :id).group_by(&:person_id)
    @open_loans.fetch(member.person_id, [])
  end

  def balance(loan) = loan.balance(as_of: paid_on)
  def amount_for(loan) = loan_amounts[loan.id]

  # What goes to the loans of a member's person (all their roles).
  def loans_total_for(member)
    open_loans(member).sum { |loan| amount_for(loan) || 0 }
  end

  def loans_total = person_lines.sum { |group| loans_total_for(group.first.member) }

  def save
    return false unless valid_request?

    ActiveRecord::Base.transaction do
      payroll.lock!
      raise ActiveRecord::Rollback unless create_payment
    end
    errors.empty?
  end

  private
    def valid_request?
      errors.add(:base, :already_paid) if payroll.payments.exists?(period_starts_on: period.starts_on)
      errors.add(:base, :nothing_to_pay) if lines.empty?
      errors.add(:base, :no_overtime_rate) if lines.any? { |line| line.overtime_hours.to_d.positive? && line.overtime_hour_rate.nil? }
      errors.add(:base, :negative_amount) if loan_amounts.values.compact.any?(&:negative?)
      known = lines.flat_map { |line| open_loans(line.member).map(&:id) }
      errors.add(:base, :unknown_loan) if (loan_amounts.compact.select { |_, amount| amount.positive? }.keys - known).any?
      person_lines.each do |group|
        pay = group.sum(&:gross_amount)
        next unless loans_total_for(group.first.member) > pay

        errors.add(:base, :over_pay, person: group.first.member.full_name, pay: money(pay))
      end
      errors.empty?
    end

    def create_payment
      @payment = payroll.payments.create!(period_starts_on: period.starts_on, period_ends_on: period.ends_on, paid_on:,
                                          observations:, money_account_id:, created_by: @user, gross_total: 0, loans_total: 0, net_total: 0)
      person_lines.each { |group| create_person_lines(group) }
      return false if errors.any?

      @payment.update!(gross_total: gross_total, loans_total: @payment.lines.sum(:loans_amount),
                       net_total: @payment.lines.sum(:net_amount))
      true
    end

    # One payment line per role; the person's deduction spread over them in
    # order, and their loan payments on the first one.
    def create_person_lines(group)
      left = loans_total_for(group.first.member)
      records = group.map do |line|
        loans_amount = [ left, line.gross_amount ].min
        left -= loans_amount
        create_line(line, loans_amount)
      end
      pay_loans(group.first.member, records.first)
    end

    def create_line(line, loans_amount)
      @payment.lines.create!(member: line.member, basis: line.basis, quantity: line.quantity, rate: line.rate,
                             gross_amount: line.gross_amount, loans_amount:,
                             overtime_hours: line.overtime_hours.to_d, overtime_hour_rate: line.overtime_hour_rate,
                             extra_days: line.extra_days.to_d, overtime_amount: line.overtime_amount.to_d)
    end

    def pay_loans(member, record)
      open_loans(member).each do |loan|
        amount = amount_for(loan)
        next unless amount&.positive?

        loan_payment = loan.payments.create(paid_on:, amount:, payment_method: LoanPayment::PAYROLL,
                                            payroll_payment_line: record, created_by: @user,
                                            observations: I18n.t("farms.payments.loan_observation", payroll: payroll.name))
        loan_payment.errors.full_messages.each do |message|
          errors.add(:base, :loan_error, loan: loan.id, detail: message)
        end
      end
    end

    def parse_amount(value)
      return if value.to_s.strip.empty?

      BigDecimal(value.to_s.delete(",").strip).round(2)
    rescue ArgumentError
      nil
    end

    def parse_date(value)
      value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def money(value)
      ActiveSupport::NumberHelper.number_to_currency(value)
    end
end
