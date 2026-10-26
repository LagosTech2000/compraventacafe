module Sales
  # A conversion's result: the coffee that came out in the new state and
  # when, weighed like a purchase (gross, sacks, humidity, damage); it adds
  # to its stock.
  class ConversionResultsController < ApplicationController
    before_action :set_conversion

    def edit
      @conversion.finished_at ||= Time.current.change(sec: 0)
      @conversion.output_humidity_percent ||= PurchaseDefaults::HUMIDITY_PERCENT.fetch(@conversion.to_state)
    end

    def update
      @conversion.assign_attributes(result_params.merge(finished_by: Current.user))
      @conversion.finishing = true

      if @conversion.save
        close_modal_with notice: t(".success", number: @conversion.display_number), fallback: sales_coffee_conversion_path(@conversion)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_conversion
        @conversion = CoffeeConversion.find(params[:coffee_conversion_id])
        authorize @conversion, :finish?
      end

      def result_params
        params.expect(coffee_conversion: [ :finished_at, :output_gross_weight, :output_sacks, :output_humidity_percent, :output_damage_percent, :lock_version ])
      end
  end
end
