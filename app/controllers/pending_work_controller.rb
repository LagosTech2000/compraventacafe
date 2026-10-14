# "Pendientes" of the home page in detail (Fernando, 2026-10-13): each kind of
# pending work with its records and the button that solves each one. Opened
# in the modal (or drawer) from the figure; only the modules the user reads.
class PendingWorkController < ApplicationController
  def show
    authorize :dashboard
    @dashboard = Dashboard.new(Current.user)
  end
end
