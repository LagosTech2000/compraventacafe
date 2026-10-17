module Administration
  class PeopleController < ApplicationController
    before_action :set_person, only: %i[ show edit update destroy ]

    def index
      authorize Person
      @filter = PersonFilter.new(params)
      @people, @next_page = @filter.results(policy_scope(Person))
    end

    def show
    end

    # role=collaborator comes checked (e.g. adding someone to a payroll).
    def new
      @person = authorize Person.new
      @person.build_collaborator if params[:role] == "collaborator"
    end

    def create
      @person = authorize Person.new(person_params)
      authorize_producer_role
      authorize_hauler_role

      if @person.save
        close_modal_with notice: t(".success"), fallback: administration_person_path(@person),
                         event: "person:created", detail: { id: @person.id, label: @person.picker_label }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      @person.assign_attributes(person_params)
      authorize_producer_role
      authorize_hauler_role

      if @person.save
        close_modal_with notice: t(".success"), fallback: administration_person_path(@person)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @person.destroy
        close_modal_with notice: t(".success"), fallback: administration_people_path
      else
        redirect_back_or_to administration_people_path, alert: @person.errors.full_messages.to_sentence
      end
    end

    private
      def set_person
        @person = authorize Person.find(params[:id])
      end

      def person_params
        params.expect(person: [ :first_names, :last_names, :dni, :rtn, :phone, :email, :zone_id, :department_id, :municipality_id,
                                :address_line, :latitude, :longitude, :photo_upload, :remove_photo,
                                :client_role, :collaborator_role, :producer_role, :producer_kind,
                                :hauler_role, :hauler_commission_percent, :hauler_can_price ])
      end

      # A producer is a Compra de café record: adding or removing the role
      # takes creating producers there.
      def authorize_producer_role
        producer = @person.producer
        authorize Producer, :create? if producer&.new_record? || producer&.marked_for_destruction?
      end

      # So is a hauler (carrero).
      def authorize_hauler_role
        hauler = @person.hauler
        authorize Hauler, :create? if hauler&.new_record? || hauler&.marked_for_destruction?
      end
  end
end
