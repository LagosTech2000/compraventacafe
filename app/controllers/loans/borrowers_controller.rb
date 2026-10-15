module Loans
  # The card beside the loan form: who the person picked is, how they pay
  # (CreditAccount) and, for a producer, the coffee they sell. Loaded into
  # its frame each time the form's picker changes (borrower_card_controller.js).
  class BorrowersController < ApplicationController
    def show
      person = authorize Person.includes(:zone, :department, :municipality, :photo_info, :client, :collaborator, producer: :farms).find(params[:id]),
                         policy_class: CreditAccountPolicy
      @account = CreditAccount.new(person)
      @producer_profile = ProducerProfile.new(person.producer) if person.producer? && policy(Producer).show?
    end
  end
end
