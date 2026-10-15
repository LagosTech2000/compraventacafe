# What a farm has produced and cost, from the records already kept
# (Fernando, 2026-10-14): the coffee bought from it (purchases that name it,
# voided ones left out), the cans picked in its harvest payrolls, what its
# payrolls paid and its expenses, and, with its land written (FarmArea),
# the same per manzana and per hectare. All dates, like the payroll
# accounts above it; Reportería narrows by period (FarmsReport).
class FarmProfile
  QUINTAL = PurchaseCalculation::QUINTAL_WEIGHT

  attr_reader :farm

  def initialize(farm)
    @farm = farm
  end

  # --- Coffee bought from the farm ------------------------------------------

  def purchases = farm.purchases.active
  def purchases_count = @purchases_count ||= purchases.count
  def net_weight = @net_weight ||= purchases.sum(:net_weight)
  def quintals = PurchaseCalculation.quintals(net_weight)
  def sales_total = @sales_total ||= purchases.sum(:total)
  # Total ÷ net pounds, as in the producer's page: an average, not a rule.
  def average_price = (sales_total / net_weight if net_weight.positive?)
  def season_quintals = PurchaseCalculation.quintals(purchases.in_season(Season.current).sum(:net_weight))

  # --- Harvest ----------------------------------------------------------------

  def harvest? = @harvest ||= farm.payrolls.where(kind: "harvest").exists?

  def cans = @cans ||= harvest_entries.sum(:cans)
  def harvest_days = harvest_entries.distinct.count(:worked_on)
  def pickers = harvest_entries.distinct.count("payroll_members.person_id")
  # What was paid for cans (payroll payments, by cans).
  def cans_paid = PayrollPaymentLine.joins(payment: :payroll).where(payrolls: { farm_id: farm.id }, basis: "harvest").sum(:gross_amount)

  # --- Cost ---------------------------------------------------------------------

  def payroll_paid = @payroll_paid ||= PayrollPayment.joins(:payroll).where(payrolls: { farm_id: farm.id }).sum(:gross_total)
  def expenses = @expenses ||= PayrollExpense.joins(:payroll).where(payrolls: { farm_id: farm.id }).sum(:amount)
  def cost = payroll_paid + expenses
  # What the coffee was worth less what the farm cost.
  def balance = sales_total - cost
  def cost_per_quintal = (cost * QUINTAL / net_weight if net_weight.positive?)

  # --- Per land -------------------------------------------------------------------

  def area = farm.area
  # From the exact quintals (net ÷ 125), not the rounded ones on screen.
  def quintals_per_manzana = (net_weight / QUINTAL / area.manzanas if area)
  def quintals_per_hectare = (net_weight / QUINTAL / area.hectares if area)
  def sales_per_manzana = (sales_total / area.manzanas if area)
  def cans_per_manzana = (cans / area.manzanas if area)

  private
    def harvest_entries
      HarvestEntry.joins("JOIN payroll_members ON payroll_members.id = harvest_entries.payroll_member_id")
                  .joins("JOIN payrolls ON payrolls.id = payroll_members.payroll_id")
                  .where(payrolls: { farm_id: farm.id })
    end
end
