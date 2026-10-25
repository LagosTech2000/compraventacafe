module Finance
  # Every peso that came in (IncomeFilter), with «Registrar ingreso» for
  # the money that comes from outside the modules (OtherIncome).
  class IncomesController < ApplicationController
    def index
      authorize [ :finance, :income ]
      @filter = IncomeFilter.new(params)
      @filter.user = Current.user
      @incomes, @next_page = @filter.results(nil)
    end
  end
end
