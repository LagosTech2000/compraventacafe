# A share of a purchase invoice in a lot (Fernando, 2026-11-13: «pueden
# incluir porcentajes de facturas sin pasarse de su peso»): a percent of
# every purchase of the invoice. Between all the lots an invoice never goes
# past 100 %, and a lot never past its limit of gross pounds. The invoice is
# of the lot's coffee state, every purchase in the lot's warehouse.
#
# The lot keeps the gross and net pounds it took (Fernando, 2026-11-13):
# when an edited purchase changes its invoice's pounds, the percent moves
# instead (`rebase!`), so a heavier purchase leaves what it adds out of
# every lot and the shipments do not change; a lighter one that no longer
# holds what its lots took is not saved (`Purchase#keeps_its_lots`,
# `Invoice#revise!`). Value, haulers' commission and the coffee taken from
# each purchase follow its net pounds against the invoice's.
class CoffeeBatchInvoice < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  belongs_to :coffee_batch, inverse_of: :batch_invoices
  belongs_to :invoice
  belongs_to :created_by, class_name: "User"

  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :invoice_id, uniqueness: { scope: :coffee_batch_id }
  validate :invoice_fits, :within_the_invoice, :within_the_limit, :lot_open

  before_validation :take_pounds, if: -> { new_record? || will_save_change_to_percent? }

  # Its fraction of each active purchase of its invoice, in SQL: its net
  # pounds against the invoice's.
  NET_SHARE_SQL = "(coffee_batch_invoices.net_weight / NULLIF((SELECT SUM(invoice_purchases.net_weight) FROM purchases invoice_purchases " \
                  "WHERE invoice_purchases.invoice_id = coffee_batch_invoices.invoice_id AND invoice_purchases.voided_at IS NULL), 0))".freeze

  # Active purchases' gross and net pounds of an invoice, without one
  # purchase or with it as it is about to be saved.
  def self.invoice_pounds(invoice_id, without: nil, with: nil)
    scope = Purchase.active.where(invoice_id:)
    scope = scope.where.not(id: without) if without
    gross, net = scope.pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)")).map(&:to_d)
    with && !with.voided? ? [ gross + with.gross_weight.to_d, net + with.net_weight.to_d ] : [ gross, net ]
  end

  # Gross and net pounds the lots took of an invoice.
  def self.taken_pounds(invoice_id)
    where(invoice_id:).pick(Arel.sql("COALESCE(SUM(gross_weight), 0)"), Arel.sql("COALESCE(SUM(net_weight), 0)")).map(&:to_d)
  end

  # An error message when the invoice, with those pounds, no longer holds
  # what its lots took; nil when it does.
  def self.shortfall(invoice_id, gross, net)
    taken_gross, taken_net = taken_pounds(invoice_id)
    return if taken_gross <= gross && taken_net <= net

    number = ->(value) { ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, delimiter: ",") }
    I18n.t("activerecord.errors.messages.below_lots", taken_gross: number.(taken_gross), taken_net: number.(taken_net), gross: number.(gross), net: number.(net))
  end

  # After its invoice's pounds changed: every lot keeps its pounds and its
  # percent becomes what they are of the invoice now (the larger of gross
  # and net, rounded up, so what is left fits both).
  def self.rebase!(invoice_id)
    gross, net = invoice_pounds(invoice_id)
    where(invoice_id:).find_each do |line|
      shares = [ [ line.gross_weight, gross ], [ line.net_weight, net ] ].filter_map { |taken, total| taken.to_d / total * 100 if total.positive? }
      percent = ((shares.max || 0) * 10_000).ceil / 10_000.to_d
      percent = percent.clamp(0.0001.to_d, 100)
      next if percent == line.percent

      line.percent = percent
      line.rebasing = true
      line.save!(validate: false)
    end
  end

  attr_accessor :rebasing

  # Percent of each invoice already in lots: { invoice id => percent }.
  def self.used_by_invoice(invoice_ids = nil)
    scope = invoice_ids ? where(invoice_id: invoice_ids) : all
    scope.group(:invoice_id).sum(:percent)
  end

  # Invoices that may go in a lot: active, of its coffee state, every
  # purchase in its warehouse, with a share left.
  def self.eligible_invoices(batch)
    Invoice.active.of_coffee_state(batch.coffee_state)
           .where.not(id: Purchase.where.not(warehouse_id: batch.warehouse_id).where.not(invoice_id: nil).select(:invoice_id))
           .where.not(id: group(:invoice_id).having("SUM(percent) >= 100").select(:invoice_id))
  end

  def audit_label = "#{invoice&.display_number} · #{coffee_batch&.label}"

  # Its value: its net pounds' part of what the invoice's purchases cost.
  def value
    active = invoice.purchases.select { it.voided_at.nil? }
    net = active.sum { it.net_weight.to_d }
    net.positive? ? (active.sum { it.total.to_d } * net_weight.to_d / net).round(2) : 0.to_d
  end

  private
    # The pounds the percent takes of the invoice now.
    def take_pounds
      return if rebasing || invoice.nil? || percent.nil?

      gross, net = self.class.invoice_pounds(invoice_id)
      self.gross_weight = (gross * percent.to_d / 100).round(6)
      self.net_weight = (net * percent.to_d / 100).round(6)
    end

    def invoice_fits
      return unless coffee_batch && invoice

      errors.add(:invoice, :not_eligible) unless self.class.eligible_invoices(coffee_batch).or(Invoice.where(id: invoice_id_in_database)).exists?(invoice.id) &&
                                                 Invoice.active.of_coffee_state(coffee_batch.coffee_state).exists?(invoice.id)
    end

    def within_the_invoice
      return unless invoice && percent

      others = self.class.where(invoice_id: invoice.id).where.not(id:).sum(:percent)
      left = 100 - others
      errors.add(:percent, :over_invoice, left: ActiveSupport::NumberHelper.number_to_rounded(left, precision: 2, strip_insignificant_zeros: true)) if percent.to_d > left
    end

    def within_the_limit
      return unless coffee_batch && invoice && percent

      others = coffee_batch.batch_invoices.where.not(id:).sum(:gross_weight).to_d
      return if others + gross_weight.to_d <= coffee_batch.gross_limit.to_d

      room = [ coffee_batch.gross_limit.to_d - others, 0 ].max
      errors.add(:percent, :over_limit, room: ActiveSupport::NumberHelper.number_to_rounded(room, precision: 2, delimiter: ","))
    end

    def lot_open
      errors.add(:base, :lot_sold) if coffee_batch&.shipment&.sold? && !CoffeeBatch.sold_editable?
    end
end
