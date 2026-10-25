require "rails_helper"

RSpec.describe Purchase, "damage types" do
  it "asks for at least one kind when parchment has damage, and keeps none without it" do
    purchase = build(:purchase, damage_percent: 2, damage_types: [])
    expect(purchase).not_to be_valid
    expect(purchase.errors[:damage_types]).to include("elige al menos uno")

    purchase.damage_types = [ "", "borer", "pulp", "borer", "unknown" ]
    purchase.save!
    expect(purchase.reload.damage_types).to eq(%w[borer pulp])
    expect(purchase.human_damage_types).to eq("Broca, Pulpa")

    purchase.update!(damage_percent: 0)
    expect(purchase.reload.damage_types).to eq([])
    expect(create(:purchase, coffee_state: "cherry", damage_types: %w[green]).damage_types).to eq([])
  end

  it "lets an older purchase with damage and no kind be voided" do
    purchase = create(:purchase, damage_percent: 2)
    purchase.update_columns(damage_types: [])
    expect(purchase.update(voided_at: Time.current, voided_by: create(:user))).to be(true)
  end
end
