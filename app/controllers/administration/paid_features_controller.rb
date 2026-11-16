module Administration
  # Turns a development quoted apart on or off, with its agreed price and
  # notes (only User::DATA_EXPORTER_ID). Audited.
  class PaidFeaturesController < ApplicationController
    def update
      authorize :maintenance, :create?
      feature = PaidFeature.find(params[:id])
      if feature.update(params.expect(paid_feature: [ :enabled, :agreed_price, :notes ]))
        redirect_back_or_to administration_control_center_path, notice: t(".success", title: feature.title)
      else
        redirect_back_or_to administration_control_center_path, alert: feature.errors.full_messages.to_sentence
      end
    end
  end
end
