# A share of a finished process in a lot (Fernando, 2026-11-16: «el café
# que sale de proceso debería poderse meter a un lote»), like an invoice's
# (CoffeeBatchInvoice): a percent of what came out of the process. Only a
# finished process (Fernando: «en curso no»), of the lot's coffee state,
# whose result went into the lot's warehouse; between all the lots a
# process never goes past 100 %, and a lot never past its limit. A lot may
# mix invoices and processes (Fernando, 2026-11-16).
#
# It keeps the gross and net pounds it took. Its value: its net part of
# what the process's coffee cost (the purchases that went in) and of its
# costs (haulers' commission and processing costs), from CoffeeLots.
class CoffeeBatchConversion < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  belongs_to :coffee_batch, inverse_of: :batch_conversions
  belongs_to :coffee_conversion
  belongs_to :created_by, class_name: "User"

  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :coffee_conversion_id, uniqueness: { scope: :coffee_batch_id }
  validate :conversion_fits, :within_the_conversion, :within_the_limit, :lot_open
  validate :coffee_in_before_it_left, if: -> { new_record? || will_save_change_to_coffee_conversion_id? }

  before_validation :take_pounds, if: -> { new_record? || will_save_change_to_percent? }

  # Percent of each process already in lots: { conversion id => percent }.
  def self.used_by_conversion(conversion_ids = nil)
    scope = conversion_ids ? where(coffee_conversion_id: conversion_ids) : all
    scope.group(:coffee_conversion_id).sum(:percent)
  end

  # Finished processes that may go in a lot: of its coffee state, whose
  # result went into its warehouse, with a share left.
  def self.eligible_conversions(batch)
    CoffeeConversion.active.where.not(finished_at: nil).where(to_state: batch.coffee_state)
                    .where("COALESCE(coffee_conversions.output_warehouse_id, coffee_conversions.warehouse_id) = ?", batch.warehouse_id)
                    .where.not(id: group(:coffee_conversion_id).having("SUM(percent) >= 100").select(:coffee_conversion_id))
  end

  # { conversion id => [purchase value, costs] } of the coffee that came
  # out of each process (CoffeeLots: the purchases that went in, their
  # commission and earlier costs, plus its processing costs).
  def self.output_values(conversion_ids, lots: CoffeeLots.new)
    return {} if conversion_ids.empty?

    processing = CoffeeConversion.processing_costs_by_conversion
    CoffeeConversion.where(id: conversion_ids).to_h do |conversion|
      taken = lots.portions_for(conversion)
      [ conversion.id, [ taken.sum(0.to_d, &:purchase_value), taken.sum(0.to_d, &:costs) + processing.fetch(conversion.id, 0).to_d ] ]
    end
  end

  def audit_label = "#{coffee_conversion&.audit_label} · #{coffee_batch&.label}"

  private
    def take_pounds
      return if coffee_conversion.nil? || percent.nil?

      self.gross_weight = (coffee_conversion.output_gross_weight.to_d * percent.to_d / 100).round(6)
      self.net_weight = (coffee_conversion.output_net_weight.to_d * percent.to_d / 100).round(6)
    end

    # A lot already on a shipment or in a process takes only a result that
    # was in the warehouse when it left (Fernando, 2026-11-18).
    def coffee_in_before_it_left
      return unless coffee_conversion&.finished_at && coffee_batch&.taken?

      entered = coffee_conversion.finished_at.in_time_zone
      errors.add(:base, CoffeeBatch.late_message(coffee_batch, entered, coffee_batch.taker)) if CoffeeBatch.after?(entered, coffee_batch.taken_at)
    end

    def conversion_fits
      return unless coffee_batch && coffee_conversion

      fits = self.class.eligible_conversions(coffee_batch).or(CoffeeConversion.where(id: coffee_conversion_id_in_database)).exists?(coffee_conversion.id)
      errors.add(:coffee_conversion, :not_eligible) unless fits && coffee_conversion.finished? && !coffee_conversion.voided?
    end

    def within_the_conversion
      return unless coffee_conversion && percent

      left = 100 - self.class.where(coffee_conversion_id: coffee_conversion.id).where.not(id:).sum(:percent)
      errors.add(:percent, :over_conversion, left: ActiveSupport::NumberHelper.number_to_rounded(left, precision: 2, strip_insignificant_zeros: true)) if percent.to_d > left
    end

    def within_the_limit
      return unless coffee_batch && percent

      others = coffee_batch.taken_gross(except: self)
      return if others + gross_weight.to_d <= coffee_batch.gross_limit.to_d

      room = [ coffee_batch.gross_limit.to_d - others, 0 ].max
      errors.add(:percent, :over_limit, room: ActiveSupport::NumberHelper.number_to_rounded(room, precision: 2, delimiter: ","))
    end

    def lot_open
      errors.add(:base, :lot_sold) if coffee_batch&.shipment&.sold? && !CoffeeBatch.sold_editable?
      # Its coffee went to be processed with these pounds (Fernando, 2026-11-16).
      errors.add(:base, :lot_processed) if coffee_batch&.processed?
      # Its shipment or process is of a closed day (BusinessDayClose).
      errors.add(:base, :lot_closed_day) if coffee_batch&.closed_day?
    end
end
