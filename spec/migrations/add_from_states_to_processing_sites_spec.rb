require "rails_helper"
require Rails.root.join("db/migrate/20261030120000_add_from_states_to_processing_sites")

# Client, 2026-10-30: each process has its own places. The places already
# registered keep the processes they were used for; one never used takes
# both. PostgreSQL rolls the DDL back with the example's transaction.
RSpec.describe AddFromStatesToProcessingSites do
  let(:migration) { described_class.new.tap { |m| m.verbose = false } }

  after { ProcessingSite.reset_column_information }

  it "gives each place the processes it was used for, and both to one never used" do
    pulper = create(:processing_site, name: "Máquina")
    dryer = create(:processing_site, name: "Secadora")
    patio = create(:processing_site, name: "Patio")
    unused = create(:processing_site, name: "Sin usar")
    create(:coffee_conversion, from_state: "cherry", processing_site: pulper)
    create(:coffee_conversion, from_state: "wet_parchment", processing_site: dryer)
    create(:coffee_conversion, from_state: "cherry", processing_site: patio)
    create(:coffee_conversion, from_state: "wet_parchment", processing_site: patio)

    migration.down
    ProcessingSite.reset_column_information
    expect(ProcessingSite.column_names).not_to include("from_states")
    migration.up
    ProcessingSite.reset_column_information

    expect(ProcessingSite.order(:id).pluck(:name, :from_states)).to eq([ [ "Máquina", %w[cherry] ], [ "Secadora", %w[wet_parchment] ],
                                                                       [ "Patio", %w[cherry wet_parchment] ], [ "Sin usar", %w[cherry wet_parchment] ] ])
    expect(unused.reload.from_states).to eq(%w[cherry wet_parchment])
  end
end
