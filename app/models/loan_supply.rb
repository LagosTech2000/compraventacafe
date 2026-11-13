# A line of supplies in a loan: how much of a supply was lent and at what
# price. The price starts at the supply's default and is kept here, so the
# loan does not change if the default changes later.
#
# Delivered or not (Fernando, 2026-11-13: «ya ingresados no quiere decir que
# ya los entregué»): a line is pending until an administrator marks it
# delivered (#deliver!), which takes it out of the warehouse; it cannot hand
# out what is not there. The interest runs from the loan's date as always.
# Loans dated before the inventory started are outside it: their lines
# count as delivered with the loan.
class LoanSupply < ApplicationRecord
  include Auditable

  belongs_to :loan
  belongs_to :supply
  belongs_to :delivered_by, class_name: "User", optional: true

  validates :quantity, numericality: { greater_than: 0, less_than: 100_000 }
  validates :unit_price, numericality: { greater_than: 0, less_than: Supply::MAX_PRICE }
  validate :delivered_from_warehouse, if: :delivery_counts?

  before_validation :compute_total
  before_validation :delivered_with_loan, on: :create

  scope :delivered, -> { where.not(delivered_on: nil) }
  scope :to_deliver, -> { where(delivered_on: nil) }

  def audit_label
    "#{supply&.name} · #{loan&.audit_label}"
  end

  def delivered? = delivered_on.present?

  # quantity × unit price, to the cent; nil until both are known.
  def self.total_for(quantity, unit_price)
    (quantity.to_d * unit_price.to_d).round(2) if quantity.present? && unit_price.present?
  end

  def deliver!(user, on: Time.zone.today)
    update!(delivered_on: on, delivered_by: user)
  end

  def undeliver!
    update!(delivered_on: nil, delivered_by: nil)
  end

  # Whether it takes from the inventory (its loan is from the day it started).
  def counted? = loan&.disbursed_on.present? && loan.disbursed_on >= SupplyStock.starts_on

  private
    def compute_total
      self.total = self.class.total_for(quantity, unit_price)
    end

    def delivered_with_loan
      self.delivered_on ||= loan.disbursed_on if loan&.disbursed_on && !counted?
    end

    def delivery_counts?
      delivered? && counted? && (will_save_change_to_delivered_on? || will_save_change_to_quantity? || will_save_change_to_supply_id?)
    end

    def delivered_from_warehouse
      there = SupplyStock.in_warehouse(supply_id, except_line: (id if persisted?))
      return if quantity.to_d <= there

      errors.add(:base, :not_in_warehouse, supply: supply&.name, unit: supply&.unit,
                                           there: ActiveSupport::NumberHelper.number_to_rounded([ there, 0 ].max, precision: 2, strip_insignificant_zeros: true))
    end
end
