class DashboardController < ApplicationController
  def show
    authorize :dashboard
    @module_keys = AppModule::KEYS.select { |key| Current.user.can?(key, :read) }
  end
end
