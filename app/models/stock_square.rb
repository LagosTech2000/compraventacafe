# «Cuadrar inventario» (Fernando, 2026-11-23: «facilitar lo de inventario …
# para que puedan cuadrar fácilmente»): every coffee state of every active
# warehouse on one page, what the system says and the gross pounds counted;
# the rows written become counts (StockCount, with their adjustment), all
# at the same moment, all or none. A row left empty is not counted.
class StockSquare
  Row = Data.define(:warehouse, :coffee_state, :gross, :net, :count) do
    def key = "#{warehouse.id}_#{coffee_state}"
  end

  attr_reader :rows, :counted_at

  def initialize(counted_at: Time.current.change(sec: 0), entries: {}, user: nil)
    @counted_at = counted_at
    @user = user
    @rows = Warehouse.active.order(:id).flat_map do |warehouse|
      stock = CoffeeStock.new(warehouse:, at: counted_at)
      Purchase::COFFEE_STATES.map do |state|
        row = stock.row(state)
        entry = entries.fetch("#{warehouse.id}_#{state}", {})
        count = (build_count(warehouse, state, entry) if entry["counted_gross"].present?)
        Row.new(warehouse:, coffee_state: state, gross: row.gross_stock.to_d.round(2), net: row.stock.to_d.round(2), count:)
      end
    end
  end

  def counts = rows.filter_map(&:count)

  # Saves every count written, or none; false when nothing was written or one fails.
  def save
    return false if counts.empty?

    StockCount.transaction do
      counts.each { |count| count.save || raise(ActiveRecord::Rollback) }
      true
    end || false
  end

  private
    def build_count(warehouse, state, entry)
      StockCount.new(warehouse:, coffee_state: state, counted_at:, created_by: @user, counted_gross: entry["counted_gross"],
                     counted_sacks: entry["counted_sacks"].presence, reason: entry["reason"].presence,
                     reason_detail: entry["reason_detail"].presence, observations: entry["observations"].presence)
    end
end
