class ProducerPolicy < ApplicationPolicy
  self.module_key = "trading"
  self.submodule_key = "producers"

  # The card beside «Nueva compra» goes with the purchases too.
  def card? = show? || user.present? && user.can?("trading.purchases", :read)
end
