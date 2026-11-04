module Loans
  # "Simulador de préstamo": a GET form; nothing is saved.
  class SimulationsController < ApplicationController
    def show
      authorize [ :loans, :simulation ]
      today = Time.zone.today
      @simulation = LoanSimulation.new(simulation_params.reverse_merge(disbursed_on: today, paid_on: today + LoanBalance::DAYS_PER_MONTH))
      @asked = params.key?(:loan_simulation)
      @simulation.validate if @asked
    end

    private
      def simulation_params
        params.fetch(:loan_simulation, {}).permit(:amount, :monthly_interest_rate, :disbursed_on, :paid_on, :interest_grace).to_h.compact_blank
      end
  end
end
