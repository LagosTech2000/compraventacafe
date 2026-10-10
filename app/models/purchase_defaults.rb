# Values the purchase form starts with, all editable. Wet parchment starts
# at 51% humidity (the client's usual value) and dry parchment at 12%;
# cherry uses a yield of 0.186 instead. Damage starts at 0%.
module PurchaseDefaults
  COFFEE_STATE = "wet_parchment".freeze
  HUMIDITY_PERCENT = { "wet_parchment" => 51, "dry_parchment" => 12 }.freeze
  DAMAGE_PERCENT = 0
  CHERRY_YIELD = BigDecimal("0.186")

  # Inputs a purchase in this coffee state starts with.
  def self.inputs_for(coffee_state)
    if coffee_state == "cherry"
      { yield_factor: CHERRY_YIELD }
    else
      { humidity_percent: HUMIDITY_PERCENT.fetch(coffee_state), damage_percent: DAMAGE_PERCENT }
    end
  end

  # What the form's calculator switches to when the coffee state changes.
  def self.by_coffee_state
    Purchase::COFFEE_STATES.index_with { |state| inputs_for(state) }
  end
end
