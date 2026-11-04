module Loans
  # "Préstamos por cosecha": each season against the others.
  class SeasonsController < ApplicationController
    def index
      authorize [ :loans, :season ]
      @seasons = LoanSeasons.new
    end
  end
end
