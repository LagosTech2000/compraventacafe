module Administration
  # The control center's hourly rate (only User::DATA_EXPORTER_ID).
  class ControlSettingsController < ApplicationController
    def update
      authorize :maintenance, :create?
      setting = ControlSetting.current
      if setting.update(params.expect(control_setting: [ :hourly_rate ]))
        redirect_back_or_to administration_control_center_path, notice: t(".success")
      else
        redirect_back_or_to administration_control_center_path, alert: setting.errors.full_messages.to_sentence
      end
    end
  end
end
