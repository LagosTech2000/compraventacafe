require "rails_helper"

RSpec.describe Addressable do
  let(:cortes) { Department.find_by!(code: "05") }
  let(:san_pedro_sula) { Municipality.find_by!(code: "0501") }
  let(:distrito_central) { Municipality.find_by!(code: "0801") }

  it "is optional" do
    expect(build(:person, department: nil, municipality: nil, address_line: nil)).to be_valid
  end

  it "accepts a municipality of the selected department" do
    person = build(:person, department: cortes, municipality: san_pedro_sula, address_line: "Col. Trejo")
    expect(person).to be_valid
    expect(person.address_parts).to eq([ "Col. Trejo", "San Pedro Sula", "Cortés" ])
  end

  it "rejects a municipality from another department" do
    person = build(:person, department: cortes, municipality: distrito_central)
    expect(person).not_to be_valid
    expect(person.errors[:municipality]).to eq([ "no pertenece al departamento seleccionado" ])
  end

  it "requires the department when a municipality is given" do
    person = build(:person, department: nil, municipality: san_pedro_sula)
    expect(person).not_to be_valid
    expect(person.errors[:department]).to be_present
  end

  it "allows a department without a municipality" do
    expect(build(:person, department: cortes, municipality: nil)).to be_valid
  end
end
