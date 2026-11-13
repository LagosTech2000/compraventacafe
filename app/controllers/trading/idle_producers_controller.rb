module Trading
  # Producers that stopped selling (Fernando, 2026-11-13). The Inicio's card
  # (#card, the last 30 of the days chosen) and the whole list (#index, in
  # the modal from the card), for whoever sees Productores.
  class IdleProducersController < ApplicationController
    def index
      authorize Producer, :index?
      @filter = IdleProducerFilter.new(params)
      @producers, @next_page = @filter.results(policy_scope(Producer))
    end

    def card
      authorize Producer, :index?
      @days = IdleProducers.days(params[:days])
      @producers = IdleProducers.scope(@days).includes(person: :zone)
                                .order("last_purchases.last_purchased_at DESC", "producers.id DESC").limit(IdleProducers::CARD_LIMIT).to_a
    end
  end
end
