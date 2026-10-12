# What the producer page summarizes, computed in SQL from the producer's
# active (not voided) purchases: totals per season, this season's mix of
# coffee states and months, and what is still to invoice or to pay.
class ProducerProfile
  SEASONS_SHOWN = 5

  SeasonRow = Data.define(:season, :purchases_count, :net_weight, :total) do
    def quintals = PurchaseCalculation.quintals(net_weight)
    # Weighted by pounds: what a pound cost on average that season.
    def average_price = net_weight.positive? ? (total / net_weight).round(2) : nil
  end

  StateRow = Data.define(:coffee_state, :purchases_count, :net_weight) do
    def quintals = PurchaseCalculation.quintals(net_weight)
  end

  attr_reader :producer, :season

  def initialize(producer, season: Season.current)
    @producer = producer
    @season = season
    @purchases = producer.purchases.active
  end

  def season_summary = @season_summary ||= PurchaseSummary.new(@purchases.in_season(season))
  def previous_season_summary = @previous_season_summary ||= PurchaseSummary.new(@purchases.in_season(Season.new(season.year - 1)))
  def all_time_summary = @all_time_summary ||= PurchaseSummary.new(@purchases)

  def season_average_price = seasons.find { |row| row.season == season }&.average_price

  # The last seasons with purchases, newest first.
  def seasons
    @seasons ||= @purchases.group(:season_year).order(season_year: :desc).limit(SEASONS_SHOWN)
      .pluck(:season_year, Arel.sql("COUNT(*)"), Arel.sql("SUM(net_weight)"), Arel.sql("SUM(total)"))
      .map { |year, count, net, total| SeasonRow.new(season: Season.new(year), purchases_count: count, net_weight: net, total:) }
  end

  def states
    @states ||= @purchases.in_season(season).group(:coffee_state).order(Arel.sql("SUM(net_weight) DESC"))
      .pluck(:coffee_state, Arel.sql("COUNT(*)"), Arel.sql("SUM(net_weight)"))
      .map { |state, count, net| StateRow.new(coffee_state: state, purchases_count: count, net_weight: net) }
  end

  # { first day of the month => quintals } for this season, in Tegucigalpa time.
  def season_months
    month = Arel.sql(Purchase.sanitize_sql_array([ "DATE_TRUNC('month', purchases.purchased_at AT TIME ZONE 'UTC' AT TIME ZONE ?)", Time.zone.tzinfo.name ]))
    @season_months ||= @purchases.in_season(season).group(month).order(month).sum(:net_weight)
      .to_h { |date, net| [ date.to_date, PurchaseCalculation.quintals(net) ] }
  end

  def first_purchased_at = dates.first
  def last_purchased_at = dates.last

  def uninvoiced = @uninvoiced ||= PurchaseSummary.new(producer.purchases.uninvoiced)
  def pending_invoices = producer.invoices.pending

  private
    def dates
      @dates ||= @purchases.pick(Arel.sql("MIN(purchased_at)"), Arel.sql("MAX(purchased_at)")) || [ nil, nil ]
    end
end
