require "rails_helper"

RSpec.describe HasAddress do
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

  describe "where it is on the map (Fernando, 2026-10-13)" do
    it "is optional, and takes both coordinates together" do
      expect(build(:person)).to be_valid
      expect(build(:person, latitude: 14.072275, longitude: -87.192136)).to be_valid.and be_located
      expect(build(:farm, latitude: 15.5, longitude: -88.0)).to be_valid

      person = build(:person, latitude: 14.07, longitude: nil)
      expect(person).not_to be_valid
      expect(person.errors[:longitude]).to be_present
      expect(build(:person, latitude: nil, longitude: -87.19).tap(&:valid?).errors[:latitude]).to be_present
    end

    it "refuses coordinates off the globe" do
      person = build(:person, latitude: 91, longitude: -181)
      expect(person).not_to be_valid
      expect(person.errors.attribute_names).to include(:latitude, :longitude)
    end
  end
end
