module Administration
  # Centro de control (Fernando, 2026-11-15; only User::DATA_EXPORTER_ID,
  # MaintenancePolicy): the developments quoted apart, which are on, their
  # hours, usefulness and price, and the global hourly rate. The data
  # maintenance tasks are its other tab (MaintenanceTasksController).
  class ControlCentersController < ApplicationController
    def show
      authorize :maintenance
      @setting = ControlSetting.current
      @features = PaidFeature.ensure_all!
    end
  end
end
