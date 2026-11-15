# What the producer page summarizes, computed in SQL from the producer's
# active (not voided) purchases: totals per season, this season's mix of
# coffee states and months, and what is still to invoice or to pay.
#
# A producer's quintals of a season are the base of the end-of-season
# retention, and «café corriente» does not add to them (Fernando,
# 2026-11-12): it is its own figure, also per season.
class ProducerProfile
  SEASONS_SHOWN = 5

  # net_weight: without café corriente (the season's quintals); common_net:
  # the café corriente apart.
  SeasonRow = Data.define(:season, :purchases_count, :net_weight, :common_net, :total) do
    def quintals = PurchaseCalculation.quintals(net_weight)
    def common_quintals = PurchaseCalculation.quintals(common_net)
    # Weighted by every pound bought: what a pound cost on average that season.
    def average_price = (net_weight + common_net).positive? ? (total / (net_weight + common_net)).round(2) : nil
  end

  StateRow = Data.define(:coffee_state, :purchases_count, :net_weight) do
    def quintals = PurchaseCalculation.quintals(net_weight)
  end

  attr_reader :producer, :season

  def initialize(producer, season: Season.current)
    @producer = producer
    @season = season
    # Only the user's own when they see only theirs (OwnedRecord).
    @purchases = producer.purchases.owned.active
  end

  def season_summary = @season_summary ||= PurchaseSummary.new(@purchases.in_season(season))
  def previous_season_summary = @previous_season_summary ||= PurchaseSummary.new(@purchases.in_season(Season.new(season.year - 1)))
  def all_time_summary = @all_time_summary ||= PurchaseSummary.new(@purchases)

  def season_average_price = seasons.find { |row| row.season == season }&.average_price

  # The season's quintals without café corriente (the retention's base), and
  # the café corriente apart.
  def season_quintals = quintals(@purchases.in_season(season).where(common_coffee: false))
  def season_common_quintals = quintals(@purchases.in_season(season).where(common_coffee: true))
  def previous_season_quintals = quintals(@purchases.in_season(Season.new(season.year - 1)).where(common_coffee: false))
  def all_time_quintals = quintals(@purchases.where(common_coffee: false))

  # The last seasons with purchases, newest first.
  def seasons
    @seasons ||= @purchases.group(:season_year).order(season_year: :desc).limit(SEASONS_SHOWN)
      .pluck(:season_year, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(net_weight) FILTER (WHERE NOT common_coffee), 0)"),
             Arel.sql("COALESCE(SUM(net_weight) FILTER (WHERE common_coffee), 0)"), Arel.sql("SUM(total)"))
      .map { |year, count, net, common, total| SeasonRow.new(season: Season.new(year), purchases_count: count, net_weight: net, common_net: common, total:) }
  end

  def states
    @states ||= @purchases.in_season(season).group(:coffee_state).order(Arel.sql("SUM(net_weight) DESC"))
      .pluck(:coffee_state, Arel.sql("COUNT(*)"), Arel.sql("SUM(net_weight)"))
      .map { |state, count, net| StateRow.new(coffee_state: state, purchases_count: count, net_weight: net) }
  end

  # { first day of the month => quintals } for this season, in Tegucigalpa time.
  def season_months
    month = Arel.sql(Purchase.sanitize_sql_array([ "DATE_TRUNC('month', purchases.purchased_at AT TIME ZONE 'UTC' AT TIME ZONE ?)", Time.zone.tzinfo.name ]))
    @season_months ||= @purchases.in_season(season).where(common_coffee: false).group(month).order(month).sum(:net_weight)
      .to_h { |date, net| [ date.to_date, PurchaseCalculation.quintals(net) ] }
  end

  def first_purchased_at = dates.first
  def last_purchased_at = dates.last

  def uninvoiced = @uninvoiced ||= PurchaseSummary.new(producer.purchases.owned.uninvoiced)
  def unpaid_invoices = @unpaid_invoices ||= producer.invoices.owned.unpaid.includes(:payments, purchases: :loan_payments).to_a
  # What is left to pay on them: what they have to pay less what was paid.
  def unpaid_balance = unpaid_invoices.sum(&:balance_due)

  private
    def quintals(purchases) = PurchaseCalculation.quintals(purchases.sum(:net_weight))

    def dates
      @dates ||= @purchases.pick(Arel.sql("MIN(purchased_at)"), Arel.sql("MAX(purchased_at)")) || [ nil, nil ]
    end
end
