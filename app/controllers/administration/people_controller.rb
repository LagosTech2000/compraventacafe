module Administration
  class PeopleController < ApplicationController
    ROLE_FILTERS = %w[clients collaborators].freeze

    before_action :set_person, only: %i[ show edit update destroy ]

    def index
      authorize Person
      @role = params[:role].presence_in(ROLE_FILTERS)
      @query = params[:q].to_s.strip

      people = policy_scope(Person).includes(:client, :collaborator).alphabetical
      people = people.public_send(@role) if @role
      people = people.search(@query) if @query.present?
      @people = people
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
        redirect_to administration_person_path(@person), notice: t(".success")
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
        redirect_to administration_person_path(@person), notice: t(".success")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @person.destroy!
      redirect_to administration_people_path, notice: t(".success"), status: :see_other
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
