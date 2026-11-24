# The day's fuel close (Fernando, 2026-11-23: «es lo mismo para ese día el
# cierre de combustible de cualquier lado que se haga»): the fuel and oil of
# the business dispatched to its vehicles that day (SupplyExit.dispatches)
# was reviewed. One per day for the whole business: made from the daily
# close of Compra de café or of Comercialización, it shows in both, and it
# is not made twice. It does not lock the dispatches.
class FuelDayClose < ApplicationRecord
  include Auditable

  belongs_to :closed_by, class_name: "User"

  validates :day, presence: true, uniqueness: true
  validates :day, not_in_future: true

  def self.for(day) = find_by(day:)

  # The day's dispatches, with their lines, vehicle and supply.
  def self.dispatches(day)
    SupplyExit.dispatches.where(exited_on: day).includes({ lines: :supply }, { vehicle: :vehicle_type }).order(:created_at, :id)
  end

  def audit_label = I18n.l(day)
end
