module Loans
  # "Cartera": what is owed today by how late it is, and by zone.
  class PortfoliosController < ApplicationController
    def show
      authorize [ :loans, :portfolio ]
      @aging = LoanAging.new
    end
  end
end
