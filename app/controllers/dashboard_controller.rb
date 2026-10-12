class DashboardController < ApplicationController
  # The home page: the business at a glance for what the user can see
  # (Dashboard), and the modules they can open.
  def show
    authorize :dashboard
    @dashboard = Dashboard.new(Current.user)
    @module_keys = @dashboard.modules
  end
end
