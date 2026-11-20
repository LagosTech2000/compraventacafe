# The notice under a person's fields (Fernando, 2026-11-18): who is already
# registered with the same DNI, RTN, phone or names (PersonDuplicates),
# asked while typing (person_duplicates_controller.js) into its own frame.
class PersonDuplicatesController < ApplicationController
  def show
    authorize Person, policy_class: PersonDuplicatePolicy
    @duplicates = PersonDuplicates.new(**params.permit(:first_names, :last_names, :dni, :rtn, :phone, :except_id).to_h.symbolize_keys)
    render layout: false
  end
end
