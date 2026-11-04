module Loans
  # "Cobrar con café": who owes and has coffee money to pay with.
  class CoffeeCollectionsController < ApplicationController
    def show
      authorize [ :loans, :coffee_collection ]
      @filter = CoffeeCollectionFilter.new(params)
      rows = CoffeeCollectionFilter.rows
      @summary = { people: rows.size, available: rows.sum(0.to_d, &:available), owed: rows.sum(0.to_d) { it.account.total_owed } }
      @rows, @next_page = @filter.results(rows)
    end
  end
end
