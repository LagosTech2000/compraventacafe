module Trading
  # The card beside the purchase form (Fernando, 2026-10-18, like the one of
  # the loan form): the producer picked, their coffee this season, what is
  # still to invoice or pay them and, for whoever sees Préstamos, what they
  # owe. Loaded into its frame each time the producer changes
  # (record_card_controller.js).
  class ProducerCardsController < ApplicationController
    def show
      @producer = authorize Producer.includes(person: %i[zone photo_info]).find(params[:id]), :show?
      @profile = ProducerProfile.new(@producer)
      @account = CreditAccount.new(@producer.person) if policy([ :loans, :credit_account ]).show?
    end
  end
end
