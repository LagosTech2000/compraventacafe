# A lot of purchased coffee (Fernando, 2026-11-13): shares (a percent) of
# purchase invoices of one coffee state, in one warehouse, up to a limit of
# gross pounds set when it is made. Lots, not invoices, go on shipments:
# each lot whole on one shipment, a shipment with one or more lots.
#
# A shipment with lots takes from the stock the coffee of its lots (that
# share of each purchase), not the oldest first; what its local scale gave
# against what its purchases say is its shrink (Shipment#shrink_*).
#
# Each invoice share keeps the gross and net pounds it took
# (CoffeeBatchInvoice): an edited purchase does not change them. Its value
# comes from its invoices' purchases, in that net part.
class CoffeeBatch < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  live_updates :sales

  NUMBERING_LOCK_KEY = 7_301_003
  MAX_POUNDS = 1_000_000

  # Its pounds and value from its invoices' purchases, in SQL (`batches` is
  # the lots' table alias): what lists, stock and costs sum.
  # Gross and net pounds are the ones each invoice share kept; value and
  # commission, its net pounds' part of its purchases.
  def self.share_sql(column, batches: "coffee_batches")
    if %w[gross_weight net_weight].include?(column.to_s)
      "(SELECT COALESCE(SUM(coffee_batch_invoices.#{column}), 0) FROM coffee_batch_invoices WHERE coffee_batch_invoices.coffee_batch_id = #{batches}.id)"
    else
      "(SELECT COALESCE(SUM(purchases.#{column} * #{CoffeeBatchInvoice::NET_SHARE_SQL}), 0) FROM coffee_batch_invoices " \
        "JOIN purchases ON purchases.invoice_id = coffee_batch_invoices.invoice_id AND purchases.voided_at IS NULL " \
        "WHERE coffee_batch_invoices.coffee_batch_id = #{batches}.id)"
    end
  end

  belongs_to :warehouse
  belongs_to :shipment, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :batch_invoices, -> { order(:id) }, class_name: "CoffeeBatchInvoice", dependent: :destroy, inverse_of: :coffee_batch
  has_many :invoices, through: :batch_invoices

  normalizes :observations, with: FieldFormats::STRIP

  validates :coffee_state, inclusion: { in: Purchase::COFFEE_STATES }
  validates :gross_limit, numericality: { greater_than: 0, less_than: MAX_POUNDS }
  validates :batched_on, presence: true
  validates :observations, length: { maximum: 500 }
  validate :limit_holds_its_coffee, if: -> { persisted? && will_save_change_to_gross_limit? }
  validate :keeps_its_invoices, if: -> { persisted? && (will_save_change_to_coffee_state? || will_save_change_to_warehouse_id?) }
  validate :fits_its_shipment, if: -> { shipment && will_save_change_to_shipment_id? }
  validate :warehouse_active, if: :will_save_change_to_warehouse_id?

  before_create :assign_number
  before_destroy :not_shipped, prepend: true

  scope :free, -> { where(shipment_id: nil) }
  scope :newest_first, -> { order(batched_on: :desc, id: :desc) }

  def self.next_number = (maximum(:number) || 0) + 1

  # A lot on a sold shipment changes only by an administrator (Fernando,
  # 2026-11-13: «los lotes deberían poder ser actualizados retroactivamente
  # por los administradores, aun después de la venta»). Outside a request,
  # nothing is locked.
  def self.sold_editable? = Current.user.nil? || Current.user.admin?

  def display_number = format("%04d", number.to_i)
  def label = I18n.t("sales.coffee_batches.label", number: display_number)
  def audit_label = label
  def human_coffee_state = Purchase.human_attribute_name("coffee_state/#{coffee_state}")
  def shipped? = shipment_id.present?

  # Its purchases' pounds and value, in its share (a voided purchase does not count).
  def totals = @totals ||= Totals.for(self)
  def gross_weight = totals.gross
  def net_weight = totals.net
  def value = totals.value
  def hauler_commission = totals.hauler_commission
  # Gross pounds still under its limit.
  def room = gross_limit.to_d - gross_weight

  def reload(*)
    @totals = nil
    super
  end

  # Gross and net pounds, value and haulers' commission of some lots, in one query.
  Totals = Data.define(:gross, :net, :value, :hauler_commission) do
    def self.zero = new(gross: 0.to_d, net: 0.to_d, value: 0.to_d, hauler_commission: 0.to_d)

    def self.for(batch) = by_batch([ batch.id ]).fetch(batch.id, zero)

    # { batch id => Totals }.
    def self.by_batch(ids)
      return {} if ids.empty?

      pounds = CoffeeBatchInvoice.where(coffee_batch_id: ids).group(:coffee_batch_id)
                                 .pluck(:coffee_batch_id, Arel.sql("SUM(gross_weight)"), Arel.sql("SUM(net_weight)")).to_h { |id, *rest| [ id, rest ] }
      money = CoffeeBatchInvoice.joins("JOIN purchases ON purchases.invoice_id = coffee_batch_invoices.invoice_id AND purchases.voided_at IS NULL")
                                .where(coffee_batch_id: ids).group(:coffee_batch_id)
                                .pluck(:coffee_batch_id, *%w[total hauler_commission].map { Arel.sql("COALESCE(SUM(COALESCE(purchases.#{it}, 0) * #{CoffeeBatchInvoice::NET_SHARE_SQL}), 0)") })
                                .to_h { |id, *rest| [ id, rest ] }
      pounds.to_h do |id, (gross, net)|
        value, commission = money.fetch(id, [ 0, 0 ])
        [ id, new(gross: gross.to_d.round(2), net: net.to_d.round(2), value: value.to_d.round(2), hauler_commission: commission.to_d.round(2)) ]
      end
    end

    def +(other) = self.class.new(gross: gross + other.gross, net: net + other.net, value: value + other.value,
                                   hauler_commission: hauler_commission + other.hauler_commission)
  end

  private
    def assign_number
      self.class.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBERING_LOCK_KEY})")
      self.number = (self.class.maximum(:number) || 0) + 1
    end

    def limit_holds_its_coffee
      errors.add(:gross_limit, :below_coffee, gross: ActiveSupport::NumberHelper.number_to_rounded(gross_weight, precision: 2, delimiter: ",")) if gross_limit.to_d < gross_weight
    end

    def keeps_its_invoices
      errors.add(:base, :has_invoices) if batch_invoices.exists?
    end

    # Of the shipment's coffee state and warehouse; the shipment not voided,
    # and not sold unless an administrator.
    def fits_its_shipment
      errors.add(:shipment, :other_coffee) unless shipment.coffee_state == coffee_state && shipment.warehouse_id == warehouse_id
      errors.add(:shipment, :closed) if shipment.voided? || (shipment.sold? && !self.class.sold_editable?)
      errors.add(:shipment, :taken) if shipment_id_in_database && shipment_id_in_database != shipment_id
    end

    def warehouse_active
      errors.add(:warehouse, :inactive) if warehouse && !warehouse.active?
    end

    def not_shipped
      return unless shipped?

      errors.add(:base, :shipped)
      throw :abort
    end
end
