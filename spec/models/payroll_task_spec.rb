require "rails_helper"

# A task's value: fixed, or quantity × price (Fernando, 2026-10-16), split
# in equal parts either way.
RSpec.describe PayrollTask do
  let(:farm) { create(:farm, area_value: 5, area_unit: "manzana") }
  let(:payroll) { create(:payroll, farm:, kind: "task") }

  def task(**attributes) = payroll.tasks.build(name: "Tarea", **attributes)

  it "keeps a fixed amount as written" do
    fixed = task(amount: 900)
    expect(fixed).to be_valid
    expect(fixed.amount).to eq(900)
  end

  it "is barrels × the price per barrel, whatever the barrel's liters, and notes the liters" do
    sprayed = task(pricing: "per_barrel", quantity: 10, unit_price: 100, barrel_liters: 200, amount: 1)
    expect(sprayed).to be_valid
    expect(sprayed.amount).to eq(1_000)

    expect(task(pricing: "per_barrel", quantity: 10, unit_price: 100, barrel_liters: 150).tap(&:valid?).amount).to eq(1_000)
    expect(task(pricing: "per_barrel", quantity: 10, unit_price: 100, barrel_liters: nil)).not_to be_valid
  end

  it "is fertilizer applied, in quintals or pounds, × its price" do
    applied = task(pricing: "per_fertilizer", quantity: "2.5", quantity_unit: "quintal", unit_price: 80)
    expect(applied).to be_valid
    expect(applied.amount).to eq(200)
    expect(task(pricing: "per_fertilizer", quantity: 2, quantity_unit: "lata", unit_price: 80)).not_to be_valid
  end

  it "is the manzanas worked × the price per manzana, up to the farm's extension" do
    worked = task(pricing: "per_manzana", quantity: 3, unit_price: "450.50")
    expect(worked).to be_valid
    expect(worked.amount).to eq(BigDecimal("1351.50"))

    too_many = task(pricing: "per_manzana", quantity: 6, unit_price: 100)
    expect(too_many).not_to be_valid
    expect(too_many.errors[:quantity]).to include("no puede pasar de la extensión de la finca (5.0 manzanas)")
  end

  it "asks for the farm's extension before paying by manzana" do
    farm.update!(area_value: nil)
    worked = task(pricing: "per_manzana", quantity: 1, unit_price: 100)
    expect(worked).not_to be_valid
    expect(worked.errors[:base]).to include("Para pagar por manzana, primero escribe la extensión de la finca.")
  end

  it "asks for a quantity and a price, and drops what the pricing does not use" do
    expect(task(pricing: "per_barrel", barrel_liters: 200)).not_to be_valid

    back_to_fixed = task(pricing: "fixed", amount: 500, quantity: 3, unit_price: 9, barrel_liters: 200, quantity_unit: "pound")
    expect(back_to_fixed).to be_valid
    expect(back_to_fixed).to have_attributes(amount: 500, quantity: nil, unit_price: nil, barrel_liters: nil, quantity_unit: nil)
  end

  it "splits a priced value in equal parts" do
    members = create_list(:payroll_member, 4, payroll:)
    sprayed = payroll.tasks.create!(name: "Fumigación", pricing: "per_barrel", quantity: 10, unit_price: 100, barrel_liters: 200,
                                    member_ids: members.map(&:id))
    expect(sprayed.shares.values).to eq([ 250 ] * 4)
  end
end
