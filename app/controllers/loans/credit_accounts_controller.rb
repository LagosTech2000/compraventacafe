module Loans
  class CreditAccountsController < ApplicationController
    def index
      authorize Person, policy_class: CreditAccountPolicy
      @filter = CreditAccountFilter.new(params)
      people, @next_page = @filter.results(policy_scope(Person, policy_scope_class: CreditAccountPolicy::Scope))
      @accounts = people.map { |person| CreditAccount.new(person) }
    end

    def show
      person = authorize Person.find(params[:id]), policy_class: CreditAccountPolicy
      @account = CreditAccount.new(person)
      # Each loan's promissory note and contract: how many times each
      # printed, and (admins) when and by whom.
      @document_prints = LoanDocumentPrints.new(@account.loans, history: policy(PrivateDocumentPrint).history?)
    end
  end
end
