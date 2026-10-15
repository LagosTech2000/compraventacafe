module Administration
  # Merging another person into this one (Fernando, 2026-10-14): first pick
  # the other person and which one stays, then choose, detail by detail,
  # whose value stays, and merge (PersonMerge). Administrators only.
  class PersonMergesController < ApplicationController
    before_action :set_people

    # With the other person picked, what blocks the merge shows up front.
    def new
      @merge = build_merge.tap(&:valid?) if @other
    end

    def create
      @merge = build_merge
      if @merge.save
        redirect_to administration_person_path(@merge.primary),
                    notice: t(".success", name: @merge.primary.full_name, other: @merge.secondary.full_name)
      else
        render :new, status: :unprocessable_content
      end
    end

    private
      def set_people
        authorize [ :administration, PersonMerge ]
        @person = Person.find(params[:person_id])
        @other = Person.where.not(id: @person.id).find_by(id: params[:other_id])
        raise ActionController::ParameterMissing, :other_id if action_name == "create" && @other.nil?

        @keep_other = params[:keep] == "other"
      end

      def build_merge
        primary, secondary = @keep_other ? [ @other, @person ] : [ @person, @other ]
        PersonMerge.new(primary:, secondary:, choices: params.fetch(:choices, {}).permit(*PersonMerge::PERSON_FIELDS.keys,
                                                                                      *PersonMerge::PRODUCER_FIELDS.keys, "photo").to_h)
      end
  end
end
