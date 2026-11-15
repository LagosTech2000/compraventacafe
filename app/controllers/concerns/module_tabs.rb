# The tabs of each module's bar and what its Resumen shows, by submodule
# (permissions per submodule, Fernando, 2026-11-12). A Resumen shows only
# the parts of the tabs the user reads; with none of them, the module opens
# on the first tab the user reads.
module ModuleTabs
  extend ActiveSupport::Concern

  # The page each submodule opens on.
  PATHS = {
    "trading" => { "purchases" => :trading_purchases_path, "invoices" => :trading_invoices_path,
                   "daily_close" => :trading_daily_close_path, "producers" => :trading_producers_path,
                   "haulers" => :trading_haulers_path, "zones" => :trading_zones_path },
    "sales" => { "shipments" => :sales_shipments_path, "sales" => :sales_sales_path, "stock" => :sales_stock_path,
                 "coffee_conversions" => :sales_coffee_conversions_path, "daily_close" => :sales_daily_close_path,
                 "buyers" => :sales_buyers_path, "carriers" => :sales_carriers_path, "vehicles" => :sales_vehicles_path,
                 "supplies" => :sales_supply_stock_path },
    "farms" => { "payrolls" => :farms_payrolls_path, "farms" => :farms_farms_path,
                 "expense_categories" => :farms_expense_categories_path },
    "loans" => { "loans" => :loans_loans_path, "credit_accounts" => :loans_credit_accounts_path,
                 "coffee_collection" => :loans_coffee_collection_path, "collection_calendar" => :loans_collection_calendar_path,
                 "portfolio" => :loans_portfolio_path, "seasons" => :loans_seasons_path,
                 "daily_close" => :loans_daily_close_path, "simulation" => :loans_simulation_path },
    "finance" => { "movements" => :finance_movements_path, "incomes" => :finance_incomes_path,
                   "expenses" => :finance_expenses_path, "investments" => :finance_investments_path,
                   "accounts" => :finance_money_accounts_path, "consolidation" => :finance_consolidation_path,
                   "budget" => :finance_budget_path, "staff" => :finance_staff_members_path,
                   "categories" => :finance_categories_path },
    "reports" => { "reports" => :reports_root_path },
    "administration" => { "people" => :administration_people_path, "farms" => :administration_farms_path,
                          "zones" => :administration_zones_path }
  }.freeze

  # The submodules whose data each Resumen shows.
  HOMES = {
    "trading" => %w[purchases invoices daily_close],
    "sales" => %w[shipments sales stock],
    "farms" => %w[payrolls farms],
    "loans" => %w[loans],
    "finance" => %w[accounts movements budget consolidation staff],
    "administration" => %w[people farms zones]
  }.freeze

  included do
    helper_method :module_home_readable?
  end

  private
    def module_home_readable?(module_key)
      Current.user.admin? || HOMES.fetch(module_key).any? { |submodule_key| Current.user.can?("#{module_key}.#{submodule_key}", :read) }
    end

    # Call after authorizing the Resumen: true when it has something to show.
    def module_home_or_first_tab(module_key)
      return true if module_home_readable?(module_key)

      submodule_key = AppModule.submodules(module_key).find { |key| Current.user.can?("#{module_key}.#{key}", :read) }
      redirect_to public_send(PATHS.fetch(module_key).fetch(submodule_key))
      false
    end
end
