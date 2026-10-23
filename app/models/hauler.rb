# Role of a Person: a carrero (Fernando, 2026-10-16). They know producers
# with coffee ready to sell, fetch it with the business's trucks and weigh
# it on the producer's account; the purchase notes it was hauled by them and
# they earn a commission, paid by the business apart from the producer.
#
# Commission = net pounds ÷ CAN_POUNDS (cans) × their can price × their
# percent. Both are required and editable; each purchase keeps the ones of
# its day (Purchase#hauler_commission_percent, #hauler_can_price). What they
# are owed (commissions of their active purchases − payments) is paid in
# HaulerPayment, each with its receipt.
class Hauler < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :trading

  CAN_POUNDS = BigDecimal("16.5")
  MAX_CAN_PRICE = 100_000

  belongs_to :person, inverse_of: :hauler
  accepts_nested_attributes_for :person
  has_many :purchases, dependent: :restrict_with_error
  has_many :payments, -> { order(:paid_on, :id) }, class_name: "HaulerPayment", dependent: :restrict_with_error, inverse_of: :hauler

  validates :commission_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :can_price, numericality: { greater_than: 0, less_than: MAX_CAN_PRICE }
  validates :person_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { joins(:person).merge(Person.alphabetical) }
  # Commissions, payments and balance of each one, in the database (lists, sorting).
  scope :with_totals, -> {
    commissions = Purchase.active.where("purchases.hauler_id = haulers.id").select("COALESCE(SUM(hauler_commission), 0)")
    paid = HaulerPayment.where("hauler_payments.hauler_id = haulers.id").select("COALESCE(SUM(amount), 0)")
    select("haulers.*", "(#{commissions.to_sql}) AS commissions_total", "(#{paid.to_sql}) AS paid_total",
           "((#{commissions.to_sql}) - (#{paid.to_sql})) AS balance_total")
  }

  delegate :full_name, :picker_label, to: :person

  # Cans and commission of a net weight with a percent and a can price.
  def self.commission(net_weight:, percent:, can_price:)
    cans = net_weight.to_d / CAN_POUNDS
    [ cans.round(2), (cans * can_price.to_d * percent.to_d / 100).round(2) ]
  end

  def audit_label = person.full_name

  # From with_totals when the list selected them; asked for otherwise.
  def commissions_total = has_attribute?(:commissions_total) ? self[:commissions_total] : purchases.active.sum(:hauler_commission)
  def paid_total = has_attribute?(:paid_total) ? self[:paid_total] : payments.sum(:amount)
  def balance = commissions_total - paid_total

  # Has purchases or payments: it stays a hauler (deactivate it instead).
  def in_use? = purchases.exists? || payments.exists?
end
