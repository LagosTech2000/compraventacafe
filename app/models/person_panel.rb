# What a person's panel shows (Fernando, 2026-11-14: «mostrando un dashboard
# con esos datos y opciones para atajos rápidos»), opened by the fingerprint
# reader: for each role the user may see, what is pending, and shortcuts to
# what the user may do for them, the most likely first (a producer: a new
# purchase; someone who only owes loans: a payment; a hauler: paying them;
# a driver: a shipment with them). Only what each module already keeps; each
# part asks its own policy, and lists only what the user sees (OwnedRecord).
class PersonPanel
  include Rails.application.routes.url_helpers

  Action = Data.define(:key, :path, :modal) do
    def label = I18n.t("person_panels.actions.#{key}")
  end

  attr_reader :person

  # policy: ->(record, query) { true/false }; scope: ->(model) { relation }
  def initialize(person, user:, policy:, scope:)
    @person = person
    @user = user
    @policy = policy
    @scope = scope
  end

  def producer = person.producer
  def hauler = person.hauler
  def staff_member = person.staff_member&.then { it if it.active? }

  # The producer's card of «Nueva compra» (its coffee, what is pending and its debt).
  def producer_card? = producer.present? && @policy.(producer, :card?)

  # Someone who is not a producer and has loans: the card of «Nuevo préstamo».
  def borrower_card? = !producer_card? && open_loans.any? && @policy.([ :loans, :credit_account ], :card?)

  def open_loans
    @open_loans ||= @policy.(Loan, :index?) ? @scope.(Loan).unpaid.where(person:).order(:due_on, :id).to_a : []
  end

  def overdue_loans = open_loans.select { it.due_on < Time.zone.today }

  def uninvoiced_count
    @uninvoiced_count ||= producer && @policy.(Purchase, :index?) ? @scope.(Purchase).uninvoiced.where(producer:).count : 0
  end

  def hauler_balance
    @hauler_balance ||= hauler && @policy.(hauler, :show?) ? hauler.balance : nil
  end

  def shipments_driving
    @shipments_driving ||= staff_member && @policy.(Shipment, :index?) ? @scope.(Shipment).in_transit.where(driver: staff_member).newest_first.to_a : []
  end

  def missing_fields = person.missing_fields

  def actions
    @actions ||= [ *producer_actions, *loan_actions, *hauler_actions, *driver_actions, *person_actions ]
  end

  private
    def producer_actions
      return [] unless producer

      list = []
      list << Action.new(:new_purchase, new_trading_purchase_path(producer_id: producer.id), false) if @policy.(Purchase, :create?)
      list << Action.new(:invoice, new_trading_invoice_path(producer_id: producer.id), false) if uninvoiced_count.positive? && @policy.(Invoice, :create?)
      list << Action.new(:producer, trading_producer_path(producer), false) if @policy.(producer, :show?)
      list
    end

    def loan_actions
      list = []
      loan = overdue_loans.first || open_loans.first
      list << Action.new(:loan_payment, new_loans_loan_payment_path(loan), true) if loan && @policy.(LoanPayment.new(loan:), :create?)
      list << Action.new(:new_loan, new_loans_loan_path(person_id: person.id), false) if @policy.(Loan, :create?)
      list << Action.new(:credit_account, loans_credit_account_path(person), false) if open_loans.any? && @policy.([ :loans, :credit_account ], :show?)
      list
    end

    def hauler_actions
      return [] unless hauler

      list = []
      list << Action.new(:hauler_payment, new_trading_hauler_payment_path(hauler), true) if hauler_balance&.positive? && @policy.(HaulerPayment, :create?)
      list << Action.new(:hauler, trading_hauler_path(hauler), false) if @policy.(hauler, :show?)
      list
    end

    def driver_actions
      return [] unless staff_member

      list = []
      list << Action.new(:new_shipment, new_sales_shipment_path(driver_id: staff_member.id), false) if @policy.(Shipment, :create?)
      list << Action.new(:staff_member, finance_staff_member_path(staff_member), false) if @policy.(staff_member, :show?)
      list
    end

    def person_actions
      list = []
      list << Action.new(:person, administration_person_path(person), false) if @policy.(person, :show?)
      list
    end
end
