module Sales
  # Resumen: the coffee in stock, what is pending at each step (weigh at
  # destination, sell, collect) and how today and the season went.
  class HomeController < ApplicationController
    def index
      authorize [ :sales, :home ]
      @stock = CoffeeStock.new
      shipments = policy_scope(Shipment)
      @in_transit = shipments.in_transit
      @unsold = shipments.unsold
      @unpaid = policy_scope(Sale).unpaid
      @unpaid_balance = SaleSummary.new(@unpaid).balance_due
      @over_tolerance = over_tolerance(shipments)
      @daily_close = SalesDailyClose.new(Time.zone.today)
      @season = Season.current
      @season_summary = SaleSummary.new(policy_scope(Sale).in_season(@season))
    end

    private
      # Shipments of the season whose scales differ more than the tolerance.
      def over_tolerance(shipments)
        return shipments.none unless WeightTolerance.percent

        ShipmentFilter.new(over_tolerance: "1", season_year: Season.current.year.to_s).apply(shipments).unscope(:includes)
      end
  end
end
