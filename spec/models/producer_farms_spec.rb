require "rails_helper"

# Producers' farms: farms of the same table as the business's, each with
# its producer. A name is looked for among that producer's farms only, in
# any case: used if it exists, created otherwise.
RSpec.describe "Producer farms" do
  let(:ana) { create(:producer) }
  let(:bruno) { create(:producer) }

  describe ProducerFarmBackfill do
    it "turns each producer's farm text into one of its farms and gives it to its purchases" do
      purchases = create_list(:purchase, 2, producer: ana)
      other = create(:purchase, producer: bruno)

      result = described_class.new([ [ ana.id, "  finca  el paraíso " ], [ bruno.id, "Finca El Paraíso" ], [ bruno.id, "" ] ]).call
      expect(result.to_h).to eq(farms_created: 2, producers: 2, purchases: 3)

      expect(ana.farms.pluck(:name)).to eq([ "finca el paraíso" ])
      expect(bruno.farms.pluck(:name)).to eq([ "Finca El Paraíso" ])
      expect(purchases.map { |purchase| purchase.reload.farm }).to all(eq(ana.farms.first))
      expect(other.reload.farm).to eq(bruno.farms.first)
    end

    it "uses the farm the producer already has, in any case, and is safe to run again" do
      farm = ana.farms.create!(name: "Las Brisas")
      purchase = create(:purchase, producer: ana)

      2.times { described_class.new([ [ ana.id, "LAS BRISAS" ] ]).call }
      expect(ana.farms.count).to eq(1)
      expect(purchase.reload.farm).to eq(farm)
    end

    it "does not take a business farm with the same name" do
      business = create(:farm, name: "El Roble")
      described_class.new([ [ ana.id, "el roble" ] ]).call
      expect(ana.farms.sole).not_to eq(business)
      expect(business.reload.producer).to be_nil
    end
  end

  it "adds a farm written in the producer form, or assigns the one it has" do
    ana.update!(new_farm_name: "Santa Rosa")
    ana.update!(new_farm_name: "santa rosa")
    ana.update!(new_farm_name: "La Esperanza")
    expect(ana.reload.farm_names).to eq("La Esperanza, Santa Rosa")
  end

  it "keeps names unique per producer and among the business's farms" do
    ana.farms.create!(name: "El Mirador")
    expect(bruno.farms.build(name: "El Mirador")).to be_valid
    expect(ana.farms.build(name: "el mirador")).not_to be_valid
    create(:farm, name: "Los Pinos")
    expect(build(:farm, name: "LOS PINOS")).not_to be_valid
    expect(ana.farms.build(name: "Los Pinos")).to be_valid
  end

  it "lets a purchase name only a farm of its producer" do
    farm = ana.farms.create!(name: "El Mirador")
    expect(build(:purchase, producer: ana, farm:)).to be_valid
    errors = build(:purchase, producer: bruno, farm:).tap(&:valid?).errors.full_messages
    expect(errors).to include("Finca no es una finca de este productor")
  end

  it "counts only the business's farms as active farms" do
    create(:farm)
    ana.farms.create!(name: "El Mirador")
    expect(Dashboard.new(create(:user, :admin)).active_farms_count).to eq(1)
  end

  it "adds several farms written in the producer form at once, without repeating" do
    ana.update!(new_farm_names: [ "Santa Rosa", "", "santa rosa", "El Mirador" ])
    expect(ana.reload.farm_names).to eq("El Mirador, Santa Rosa")
  end

  it "lets a farm change owner only while no purchase or payroll names it" do
    farm = create(:farm, name: "La Vega")
    expect(farm.update(producer: ana)).to be(true)
    create(:purchase, producer: ana, farm:)
    expect(farm.update(producer: bruno)).to be(false)
    expect(farm.errors.full_messages).to include("Productor no se puede cambiar: la finca ya tiene compras o planillas")
  end
end
