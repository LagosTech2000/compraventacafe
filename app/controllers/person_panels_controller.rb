# A person's panel (Fernando, 2026-11-14): what opens, in the modal or the
# drawer, when someone puts a finger on the reader. Who it is and, for each
# role the user may see, what is pending, with shortcuts to what can be
# done for them (PersonPanel).
class PersonPanelsController < ApplicationController
  def show
    person = Person.includes(:zone, :photo_info, :client, :collaborator, :hauler, producer: :person, staff_member: :role).find(params[:id])
    authorize person, policy_class: PersonPanelPolicy
    @panel = PersonPanel.new(person, user: Current.user, policy: ->(record, query = :show?) { policy(record).public_send(query) },
                                     scope: ->(model) { policy_scope(model) })
  end
end
