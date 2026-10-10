require "rails_helper"

RSpec.describe "Loans with supplies" do
  let(:fertilizer) { create(:supply, name: "Abono 18-46-0", default_price: 1_250) }

  it "makes the principal the cash plus the supplies, and names the kind" do
    loan = create(:loan, cash_amount: 3_000, supply_items_attributes: [ { supply_id: fertilizer.id, quantity: 4, unit_price: 1_200 } ])
    expect(loan.principal).to eq(7_800)
    expect(loan.supply_items.first.total).to eq(4_800)
    expect(loan.kind).to eq("mixed")
    expect(loan.human_kind).to eq("Mixto")

    expect(create(:loan, cash_amount: 0, supply_items_attributes: [ { supply_id: fertilizer.id, quantity: 2, unit_price: 1_250 } ]))
      .to have_attributes(kind: "supplies", principal: 2_500)
    expect(create(:loan, cash_amount: 500)).to have_attributes(kind: "cash", principal: 500)
  end

  it "runs interest on the whole principal, supplies included" do
    loan = create(:loan, cash_amount: 0, monthly_interest_rate: 3, disbursed_on: Date.new(2026, 1, 1), due_on: Date.new(2026, 3, 1),
                         supply_items_attributes: [ { supply_id: fertilizer.id, quantity: 8, unit_price: 1_250 } ])
    expect(loan.balance(as_of: Date.new(2026, 1, 31)).interest_owed).to eq(300)
  end

  it "refuses a loan with nothing lent, in Spanish" do
    loan = build(:loan, cash_amount: 0)
    expect(loan).not_to be_valid
    expect(loan.errors.full_messages).to include("Agrega efectivo, insumos o ambos: el préstamo no puede quedar en cero.")
  end

  it "ignores empty supply lines and drops the ones marked for removal" do
    loan = create(:loan, cash_amount: 100, supply_items_attributes: [ { supply_id: "", quantity: "" },
                                                                     { supply_id: fertilizer.id, quantity: 1, unit_price: 50 } ])
    expect(loan.supply_items.count).to eq(1)
    loan.update!(supply_items_attributes: [ { id: loan.supply_items.first.id, _destroy: "1" } ])
    expect(loan.reload).to have_attributes(principal: 100, kind: "cash")
  end

  it "validates supply lines and supplies in Spanish" do
    loan = build(:loan, supply_items_attributes: [ { supply_id: fertilizer.id, quantity: 0, unit_price: 1 } ])
    expect(loan).not_to be_valid
    expect(Supply.new(name: "", unit: "", default_price: 0).tap(&:valid?).errors.full_messages)
      .to include("Nombre no puede estar en blanco", "Unidad no puede estar en blanco", "Precio predeterminado (L) debe ser mayor que 0")
    create(:supply, name: "Urea")
    expect(build(:supply, name: " urea ")).not_to be_valid
  end

  it "keeps a supply that was lent from being deleted" do
    create(:loan, supply_items_attributes: [ { supply_id: fertilizer.id, quantity: 1, unit_price: 1 } ])
    expect(fertilizer.destroy).to be(false)
  end
end
