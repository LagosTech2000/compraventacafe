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

    def new
      @person = authorize Person.new
    end

    def create
      @person = authorize Person.new(person_params)
      @person.assign_roles(**role_params)

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
      @person.assign_roles(**role_params)

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
        params.expect(person: [ :first_names, :last_names, :dni, :rtn, :phone, :email, :department_id, :municipality_id, :address_line ])
      end

      def role_params
        roles = params.fetch(:person, {})
        { client: roles[:client_role], collaborator: roles[:collaborator_role] }
      end
  end
end
