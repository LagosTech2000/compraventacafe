# A farm's land in each unit. It is written in one (the user's choice) and
# the others are calculated from it. A manzana is 6,988.96 m² (Fernando,
# 2026-10-14); a hectare, 10,000 m².
class FarmArea
  SQUARE_METERS = {
    "manzana" => BigDecimal("6988.96"),
    "hectare" => BigDecimal("10000"),
    "square_meter" => BigDecimal("1")
  }.freeze
  UNITS = SQUARE_METERS.keys.freeze

  attr_reader :value, :unit

  def initialize(value, unit)
    @value = BigDecimal(value.to_s)
    @unit = unit
  end

  def in(target) = value * SQUARE_METERS.fetch(unit) / SQUARE_METERS.fetch(target)

  def manzanas = self.in("manzana")
  def hectares = self.in("hectare")
  def square_meters = self.in("square_meter")

  # The area in square meters in SQL, from a table's area_value and
  # area_unit (NULL without an area): for sums, sorting and reports.
  def self.square_meters_sql(table = "farms")
    cases = SQUARE_METERS.map { |unit, factor| "WHEN '#{unit}' THEN #{factor.to_s("F")}" }.join(" ")
    "(#{table}.area_value * CASE #{table}.area_unit #{cases} END)"
  end

  # The same area in the given unit, in SQL.
  def self.sql_in(unit, table = "farms")
    "(#{square_meters_sql(table)} / #{SQUARE_METERS.fetch(unit).to_s("F")})"
  end
end
