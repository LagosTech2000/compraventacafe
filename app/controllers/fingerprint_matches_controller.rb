# Who a finger is, for the page that heard it (fingerprint.js, Fernando,
# 2026-11-14): a page with a person field fills it, one with its own action
# for a person goes there, any other opens the person's panel. What each
# picker would choose comes only for the kinds the user may search.
class FingerprintMatchesController < ApplicationController
  def show
    person = Person.includes(:zone, :hauler, :staff_member, producer: { farms: [], person: :zone }).find(params[:id])
    authorize person, policy_class: PersonPanelPolicy
    searches = PickerSearchPolicy.new(Current.user, :picker_search)
    producer = person.producer

    render json: {
      person_id: person.id, name: person.full_name, panel_url: person_panel_path(person),
      producer_id: producer&.id, hauler_id: person.hauler&.id, staff_member_id: person.staff_member&.then { it.id if it.active? },
      pickers: {
        producers: (PickerSearch.data(producer) if producer && searches.producers?),
        people: (PickerSearch.data(person) if searches.people?),
        collaborators: (PickerSearch.data(person) if person.collaborator? && searches.collaborators?)
      }.compact
    }
  end
end
