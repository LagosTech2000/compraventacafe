module Administration
  # A producer's record (kind, IHCAFE code, farms and person) edited from its
  # person's page in Administración (Fernando, 2026-10-14), with the
  # Administración permissions (Administration::ProducerPolicy).
  class ProducersController < ApplicationController
    before_action :set_producer

    def edit
    end

    def update
      if @producer.update(producer_params)
        close_modal_with notice: t(".success"), fallback: administration_person_path(@producer.person)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_producer
        @producer = Producer.find(params[:id])
        authorize [ :administration, @producer ]
      end

      def producer_params
        params.expect(producer: [
          :kind, :ihcafe_code, new_farm_names: [],
          person_attributes: [ :id, :first_names, :last_names, :dni, :rtn, :phone, :email, :zone_id,
                               :department_id, :municipality_id, :address_line, :latitude, :longitude,
                               :photo_upload, :remove_photo, :client_role, :collaborator_role ]
        ])
      end
  end
end
