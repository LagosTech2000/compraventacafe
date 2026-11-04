require "rails_helper"

# The farms' expense categories go in two levels (Fernando, 2026-11-03).
RSpec.describe ExpenseCategory do
  let(:transport) { create(:expense_category, name: "Transporte") }

  it "names a subcategory with its first level" do
    fuel = create(:expense_category, name: "Combustible", parent: transport)

    expect(fuel.full_name).to eq("Transporte › Combustible")
    expect(fuel.audit_label).to eq("Transporte › Combustible")
    expect(fuel.root).to eq(transport)
    expect(transport.full_name).to eq("Transporte")
    expect(transport.children).to eq([ fuel ])
  end

  it "keeps a name unique among its siblings only" do
    create(:expense_category, name: "Combustible", parent: transport)
    machinery = create(:expense_category, name: "Maquinaria")

    expect(build(:expense_category, name: "combustible", parent: transport)).not_to be_valid
    expect(build(:expense_category, name: "Combustible", parent: machinery)).to be_valid
    expect(build(:expense_category, name: "transporte")).not_to be_valid
  end

  it "allows only two levels" do
    fuel = create(:expense_category, name: "Combustible", parent: transport)

    third = build(:expense_category, name: "Diésel", parent: fuel)
    expect(third).not_to be_valid
    expect(third.errors[:parent]).to include("debe ser una categoría de primer nivel")

    transport.parent = create(:expense_category, name: "Varios")
    expect(transport).not_to be_valid
    expect(transport.errors[:parent]).to include("no se puede poner: esta categoría tiene subcategorías")
  end

  it "lists the options with each first level followed by its subcategories, the active ones only" do
    tools = create(:expense_category, name: "Herramientas")
    fuel = create(:expense_category, name: "Combustible", parent: transport)
    old = create(:expense_category, name: "Pasajes", parent: transport, active: false)

    expect(described_class.options).to eq([ [ "Herramientas", tools.id ], [ "Transporte", transport.id ],
                                            [ "Transporte › Combustible", fuel.id ] ])
    expect(described_class.options(including: old.id).map(&:last)).to include(old.id)
    expect(described_class.family_ids(transport.id)).to contain_exactly(transport.id, fuel.id, old.id)
  end
end
