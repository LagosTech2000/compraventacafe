# "Cobrar con café" reads the loans and the coffee purchases: it takes seeing
# both modules. Paying from it is the pago con café (creating in loans).
module Loans
  class CoffeeCollectionPolicy < ApplicationPolicy
    self.module_key = "loans"

    def show?
      super && user.can?("trading", :read)
    end

    def settle?
      show? && can?(:create)
    end
  end
end
