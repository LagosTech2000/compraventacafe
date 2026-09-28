require "rails_helper"

RSpec.describe HondurasDivisions do
  it "has the 18 departments and 298 municipalities" do
    expect(Department.count).to eq(18)
    expect(Municipality.count).to eq(298)
  end

  it "keeps each municipality under the department its code says" do
    mismatched = Municipality.includes(:department).reject { |m| m.code.start_with?(m.department.code) }
    expect(mismatched).to be_empty
  end

  it "is idempotent" do
    expect { described_class.load! }.not_to change { [ Department.count, Municipality.count ] }
  end

  it "knows well-known places" do
    expect(Municipality.find_by!(code: "0801")).to have_attributes(name: "Distrito Central")
    expect(Municipality.find_by!(code: "0501").department.name).to eq("Cortés")
  end
end
