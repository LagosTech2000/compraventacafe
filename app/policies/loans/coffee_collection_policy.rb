# "Cobrar con café" reads the loans and the coffee purchases: it takes seeing
# both modules (its purchases). Paying from it is the pago con café (creating in loans).
module Loans
  class CoffeeCollectionPolicy < ApplicationPolicy
    self.module_key = "loans"
    self.submodule_key = "coffee_collection"

    def show?
      super && user.can?("trading.purchases", :read)
    end

    # The pago con café: creating loan payments.
    def settle?
      show? && user.can?("loans.loans", :create)
    end
  end
end
