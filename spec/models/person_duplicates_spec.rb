require "rails_helper"

# People that look like the one being written (Fernando, 2026-11-18).
RSpec.describe PersonDuplicates do
  let!(:ana) { create(:person, first_names: "Ana María", last_names: "Mejía Zelaya", dni: "0801199912345", phone: "99990000") }

  it "finds the same DNI, phone or names, ignoring case, accents and dashes" do
    expect(described_class.new(dni: "0801-1999-12345").matches.map(&:reasons)).to eq([ [ :dni ] ])
    expect(described_class.new(phone: "+504 9999-0000").matches.sole.person).to eq(ana)
    expect(described_class.new(first_names: "ana", last_names: "mejia").matches.sole.reasons).to eq([ :name ])
    expect(described_class.new(first_names: "Ana", last_names: "Mejía", phone: "99990000").matches.sole.reasons).to eq(%i[phone name])
  end

  it "says nothing for a different person, half a name, a short number or itself" do
    expect(described_class.new(first_names: "Ana", last_names: "Pérez").matches).to be_empty
    expect(described_class.new(first_names: "Ana", last_names: "M").matches).to be_empty
    expect(described_class.new(dni: "0801").matches).to be_empty
    expect(described_class.new(first_names: "Ana", last_names: "Mejía", except_id: ana.id).matches).to be_empty
  end
end
