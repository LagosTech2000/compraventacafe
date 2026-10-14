# The coffee exchange card of the home page (CoffeeMarket), loaded apart in a
# lazy frame so the page never waits for the outside service.
class CoffeeMarketsController < ApplicationController
  def show
    authorize :dashboard
    @quotes = CoffeeMarket.quotes
  end
end
